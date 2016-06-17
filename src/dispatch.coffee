# Dispatch actions
# ================
# Holds all actions and dispatch according to input script.
# It comes with 3 'core' modules: "exec", "env" and "log".
# All others are extend-ed from plugins.

child_process = require 'child_process'
shell = require 'shelljs'
Q = require 'q'
util = require 'util'

logging = require './logging'
Config = require './config'
Utils = require './utils'

# commands to copy from shelljs into globals.
ShellCommands = [
  "cat", "cd", "chmod", "cp", "dirs", "exit", "grep",
  "ls", "mkdir", "mv", "popd", "pushd", "pwd", "sed", "test"
]

Dispatch =
  extend: (actions) ->
    knownActions = Object.keys @

    for action of actions
      if knownActions.indexOf(action) isnt -1
        throw new Error "Action #{action} is already defined!"
      @[action] = actions[action]

  ###
  EXEC:
  ###
  exec: (command, settings, pStdout = true) ->
    logging.debug "Uncooked command: #{command}"

    command = Utils.parseCommand command, settings, (settingValue) ->
      if 'array' is Utils.toType settingValue
        settingValue.join ' '
      else settingValue

    logging.info "+ Decoded: #{command}"
    logging.debug "Settings: #{util.inspect settings, undefined, 4}"

    # I promise...
    deferred = Q.defer()
    promise = deferred.promise

    # If first argument is one of the ShellCommands list, use shelljs instead.
    argv = command.split ' '
    if ShellCommands.indexOf(argv[0]) isnt -1
      shellCmd = shell[argv[0]]
      if typeof shellCmd is 'function'
        shellCode = shell[argv[0]].apply @, argv[1...]
      else
        shellCode = shellCmd
      logging.debug "shell command '#{command}' returned '#{JSON.stringify shellCode, undefined, 4}'"
      # check return value
      if err = shell.error()?[...-1]
        deferred.reject "Command '#{command}' returned '#{err}'"
      deferred.resolve !!shellCode
    else
      execSettings = env: settings.exec.env
      execSettings.cwd ?= process.cwd()

      # We do not (yet?) handle stdin, we want to monitor stdout, to simply
      # output stderr and to receive messages from the children thru an ipc channel.
      # At the moment it is activated everytime. It might be an issue with some
      # commands, which would lead to a complete crash.
      # We'll see when that happens :)
      if pStdout
        execSettings.stdio = [null, process.stdout, process.stderr, "ipc"]
      else
        execSettings.stdio = [null, "pipe", process.stderr, "ipc"]

      stdout = ""
      exitCode = 0

      command = [ settings.exec.shellCmd, settings.exec.shellArgs, command ]

      p = child_process.spawn command[0], command[1...], execSettings
      logging.debug "spawn #{p.pid}: #{util.inspect(command)}"

      p.on 'error', (error) ->
        deferred.reject "Child error: #{util.inspect error}"

      p.stdout?.on 'data', (chunk) ->
        stdout += chunk.toString()
        logging.debug "stdout: #{stdout}"
        return

      # If we have something in stdout, we will wait till all streams are closed.
      # Otherwise assume the exit code as the resolved promise.
      p.on 'exit', (code) ->
        exitCode = code

      p.on 'close', (code, signal) ->
        logging.debug "spawn #{p.pid} finished: #{stdout}"

        # Remove last character (\n) if we actually have something in stdout
        if stdout.length > 0
          deferred.resolve stdout?[...-1]
        else
          deferred.resolve !exitCode

      # # IPC channel back propagates environment to parent
      p.on 'message', (message) ->
        # We expect a message with an array of results.
        # NOTE: that may or may not interfere with programs already using IPC.
        if 'array' isnt Utils.toType message.results
          logging.info "IPC message #{util.inspect message, undefined, 4} not understood"
        else
          message.results.forEach (result, index) ->
            if !!result.ok
              logging.debug "Result #{index} is ok, committing."
              Utils.extend settings.exec.env, result.env
            else
              logging.error "Result #{index} is *NOT* ok. Result: #{util.inspect result}"

      promise.process = p
    promise

  env: (command, settings) ->
    logging.info "+ Set environment: #{util.inspect command, undefined, 4}"

    if typeof command is 'string'
      # Evaluate right hand side using shell command "echo"
      # m[1] contains key   m[2] contains value
      if m = command.match Config.SETTING_RE
        @exec("echo #{m[2]}", settings, false).then (result) ->
          # We propagate changes upstream to build global environment
          env = {}
          env[m[1]] = result
          [true, env]
      else
        throw new Error "Invalid environment setting: #{command}"
    else
      # Utils.extend envSettings, command
      logging.debug "Environment: #{util.inspect command, undefined, 4}"
      Q [true, command]

  # Log things :)
  # Command may have a subkey indicating log level (by default notice).
  # Ex:
  #   - log: "This is a 'notice' message version %version%"
  #   - log: warn: "This is a warning !"
  #   - log: debug: "This will be shown in debug mode only."
  log: (command, settings) ->
    if "string" is Utils.toType command
      level = "notice"
      output = command
    else
      cmdKeys = Object.keys command
      unless level = cmdKeys[0]
        throw new Error "#{level} in #{command} is invalid!"

      output = command[level]

    toLog = Utils.parseCommand output, settings, (settingValue) ->
      if 'array' is Utils.toType settingValue
        settingValue.join ' '
      else settingValue

    logging[level] toLog, settings.colors[level]
    Q true

module.exports = Dispatch
