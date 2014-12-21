child_process = require 'child_process'
shell = require 'shelljs'
Q = require 'q'
util = require 'util'
_ = require 'underscore'

logging = require './logging'
{Config} = require './config'
Utils = require './utils'

# commands to copy from shelljs into globals.
ShellCommands = [
  "cat", "cd", "chmod", "cp", "dirs", "env", "exit", "find", "grep",
  "ls", "mkdir", "mv", "popd", "pushd", "pwd", "rm", "sed", "test", "which"
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
    logging.info "+ #{command}"
    matches = command.match Config.REPLACE_SETTING_RE

    if matches
      matches.forEach (settingToReplace) ->
        # Remove leading '%'
        lookupSetting = settingToReplace[1...]
        unless settingValue = settings[lookupSetting]
          throw new Error "Setting '#{lookupSetting}' not found for command '#{command}!'"

        if 'array' is Utils.toType settingValue
          settingValue = settingValue.join ' '

        command = command.replace settingToReplace, settingValue

    # Make a new promise
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
      deferred.resolve shellCode ? 'success'
    else
      execSettings = _.clone settings.exec or {}
      execSettings.env ?= process.env
      execSettings.cwd ?= process.cwd()

      # We do not (yet?) handle stdin, we want to monitor stdout, to simply
      # output stderr and to receive messages from the children thru an ipc channel.
      # At the moment it is activated everytime. It might be an issue with some
      # commands, which would lead to a complete crash.
      # We'll see when that happens :)
      execSettings.stdio = [null, "pipe", process.stderr, "ipc"]

      stdout = ""

      # FIXME: will need to work on portability
      command = [ "/bin/sh", "-c", command ]

      p = child_process.spawn command[0], command[1...], execSettings
      logging.debug "spawn #{p.pid}: #{util.inspect(command)}"

      p.on 'error', (error) ->
        deferred.reject new Error "Child error: #{util.inspect error}"

      # live stream output
      p.stdout.on 'data', (chunk) ->
        stdout += chunk
        if pStdout
          process.stdout.write chunk

      p.on 'close', (code, signal) ->
        logging.debug "spawn #{p.pid} finished"

        # Remove last character (\n)
        deferred.resolve stdout?[...-1]

      # IPC channel back propagates environment to parent
      p.on 'message', (message) ->
        settings.exec.env = message.tasks.settings.exec.env

      promise.process = p
    promise

  env: (command, settings) ->
    logging.info "+ #{command}"

    # We will propagate changes upstream to build global environment
    envSettings = settings.exec ? {}
    envSettings.env ?= process.env

    # Evaluate right hand side using shell command "echo"
    # m[1] contains key   m[2] contains value
    if m = command.match Config.SETTING_RE
      @exec("echo #{m[2]}", settings, false).then (result) ->
        return envSettings.env[m[1]] = result
    else
      throw new Error "Invalid environment setting: #{command}"

  # Log things :)
  # Command may have a subkey indicating log level (by default notice).
  # Ex:
  #   - log: "This is a 'notice' message version %version"
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

    matches = output.match Config.REPLACE_SETTING_RE

    if matches
      matches.forEach (settingToReplace) ->
        # Remove leading '%'
        lookupSetting = settingToReplace[1...]
        unless settingValue = settings[lookupSetting]
          throw new Error "Setting '#{lookupSetting}' not found for command '#{output}!'"

        if 'array' is Utils.toType settingValue
          settingValue = settingValue.join ' '

        output = output.replace settingToReplace, settingValue

    logging[level] output
    Q true

module.exports = Dispatch
