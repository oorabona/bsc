###
Unified Build System -- Yet another build system for Coffee/NodeJS

Usage:
$ ubs
> shows possible tasks
###

fs = require 'fs'
nopt = require 'nopt'
path = require 'path'
Q = require 'q'
sprintf = require 'sprintf'
util = require 'util'
vm = require 'vm'
CoffeeScript = require 'coffee-script'
yaml = require 'js-yaml'
_ = require 'underscore'

{toType,recursiveMerge} = require './utils'

logging = require "./logging"
{Config} = require "./config"
Dispatch = require "./dispatch"
plugins = require "./plugins"

SETTING_RE = /^(\w[-\.\w]*)=(.*)$/
TASK_REGEX = /^[a-z][-a-z0-9_]*$/
DEFAULT_TASK = 'install'

longOptions =
  build: [ path, null ]
  watch: Boolean
  version: Boolean
  help: Boolean
  tasks: Boolean
  verbose: Boolean
  debug: Boolean
  "no-colors": Boolean
  colors: Boolean
  "no-builtins": Boolean

shortOptions =
  b: [ "--build"]
  w: [ "--watch" ]
  v: [ "--verbose" ]
  D: [ "--debug" ]
  t: [ "--tasks" ]

main = ->
  options = parseOptions process.argv
  return showHelp() if options.help
  return showVersion() if options.version

  run(options)
  .then (result) ->
    if options.tasks
      logging.notice "Tasks found in #{options.build}:"
      result.forEach (task) ->
        logging.notice "- #{task}" if task isnt 'settings'
    else
      logging.notice "Build complete: #{result.join '\n'}"
    process.exit result
  , (error) ->
    logging.error error.message
    if options.debug
      logging.info error.stack
    process.exit 1
  , (progress) ->
    logging.info "Progress: #{progress}"
    return

run = (options) ->
  logging.debug "Command-line options #{util.inspect _.omit(options, "argv")}: tasks #{options.argv.remain}"
  Q.fcall (resolve) ->
    rules = unless options["no-builtins"] then Config.builtinRules() else {}
    tasklist = parseTaskList options, rules.settings
    if tasklist[0].length is 0
      options.tasklist = [ DEFAULT_TASK ]
    else
      options.tasklist = tasklist[0]

    logging.debug "Loaded rules: #{util.inspect rules}"
    # Load build.yml or result of options.build
    buildFile = options.build

    Q.Promise (resolve, reject, notify) ->
      fs.readFile buildFile, "utf-8", (error, code = {}) ->
        reject(new Error error) if error

        resolve recursiveMerge rules, yaml.safeLoad code, yaml.JSON_SCHEMA

  .then (tasks) ->
    logging.debug "Tasks #{util.inspect tasks, undefined, 4}"

    # If we have init then parse it before all other action
    # At the moment only 'plugins' is recognized but it may allow future
    # extensions hopefully quite easily !
    if tasks.init?.plugins
      # If build specifies additional pluginPath then add them now
      addPluginPath = (path) ->
        plugins.addPath path
        logging.debug "Plugin path #{path} added."
        return

      if tasks.settings.pluginPath instanceof Array
        tasks.settings.pluginPath.forEach addPluginPath
      else if tasks.settings.pluginPath
        addPluginPath tasks.settings.pluginPath

      logging.info "Plugins loading path: #{plugins.getPaths()}"

      # Plugin load is asynchronous
      Q.all tasks.init.plugins.map (plugin) ->
        logging.info "Loading plugin: #{plugin}"
        plugins.load plugin, tasks
    else
      [tasks]
  .then (context) ->
    if options.tasks
      return Object.keys context[0]

    logging.debug "Looking for targets: #{options.tasklist}"

    tasks = context[0]
    runList = []
    for task in options.tasklist then do (task) ->
      pipeline = tasks[task]
      unless pipeline
        throw new Error "Could not find task #{task}"
      loop
        step = pipeline.shift()
        break unless step
        if 'string' is toType step
          runList.push type: 'exec', cmd: step
        else if step.exec
          runList.push type: 'exec', cmd: step.exec
        else if step.task
          pipeline = tasks[step.task].concat pipeline
          logging.debug "New dependant task #{step.task}"
        else
          throw new Error "Action unrecognized: #{step}"

    logging.debug "Sequence loaded: #{util.inspect runList}"

    results = []
    next = (runList) ->
      item = runList.shift()
      return unless item
      Dispatch["run_#{item.type}"](item.cmd, tasks.settings).then (result) ->
        results.push result
        next runList
      , (error) ->
        throw "While processing #{item.cmd}: #{util.inspect error}"
    next runList

parseOptions = (argv, slice) ->
  options = nopt(longOptions, shortOptions, argv, slice)
  if options.colors then logging.useColors(true)
  if options["no-colors"] then logging.useColors(false)
  if options.verbose then logging.setVerbose(true)
  if options.debug then logging.setDebug(true)
  options.build ?= process.env["UBS_BUILD"] ? Config.DEFAULT_BUILD_FILE
  options

parseTaskList = (options, settings={}) ->
  tasklist = []
  for word in options.argv.remain
    if word.match TASK_REGEX
      tasklist.push word
    else if (m = word.match SETTING_RE)
      segments = m[1].split(".")
      obj = settings
      for segment in segments[0...-1]
        obj = (obj[segment] or= {})
      obj[segments[segments.length - 1]] = m[2]
    else
      throw new Error("I don't know what to do with '#{word}'")
  options.tasklist = tasklist
  [ tasklist, settings ]

showVersion = ->
  console.log "ubs version #{Config.version()}"
  0

showHelp = ->
  console.log HELP
  0

HELP = """
ubs #{Config.version()}
usage: ubs [options] [task-setting]* [task-name]*
general options are listed below. task-settings are all of the form
"<name>=<value>".
example:
  ubs -b #{Config.DEFAULT_BUILD_FILE} build debug=true test
  loads build from #{Config.DEFAULT_BUILD_FILE}, adds { debug: "true" } to the
  global settings object, then runs task "build" followed by task "test".
options:
  --buildfile FILENAME (-b)
      use a specific rules file (default: #{Config.DEFAULT_BUILD_FILE})
  --tasks (-t)
      show the list of tasks and their descriptions
  --watch (-w)
      keep running (until killed), watching for changed files
  --help
      this help
  --version
      show the version string and exit
  --verbose (-v)
      log more about what it's doing
  --debug (-D)
      log quite a lot more about what it's thinking
  --colors / --no-colors
      override the color detection to turn on/off terminal colors
"""

exports.main = main