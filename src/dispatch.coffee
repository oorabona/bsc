child_process = require 'child_process'
shell = require 'shelljs'
Q = require 'q'
util = require 'util'

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
      
  exec: (command, settings) ->
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
    argv = command.split(' ')
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
      # i bet this doesn't work on windows.
      command = [ "/bin/sh", "-c", command ]

      localSettings = settings.exec or {}
      localSettings.env ?= process.env
      localSettings.cwd ?= process.cwd()
      localSettings.stdio ?= "inherit"

      p = child_process.spawn command[0], command[1...], localSettings
      logging.debug "spawn #{p.pid}: #{util.inspect(command)}"
      p.on "exit", (code, signal) ->
        if signal?
          deferred.reject(new Error("Killed by signal: #{signal}"))
        else if code? and code != 0
          deferred.reject(new Error("Exit code: #{code}"))
        else
          logging.debug "spawn #{p.pid} finished"
          deferred.resolve(p)
      p.on "error", (error) ->
        logging.error error.message
        deferred.reject(error)

      promise.process = p
    promise

  env: (command, settings) ->
    logging.info "+ #{command}"
    envSettings = settings.exec or {}
    envSettings.env ?= process.env

    if m = command.match Config.SETTING_RE
      segments = m[1].split "."
      for segment in segments[0...-1]
        envSettings.env = (envSettings.env[segment] or= {})
      envSettings.env[segments[segments.length - 1]] = m[2]
    else
      throw new Error "Invalid environment setting: #{env_kv}"

    Q true

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
