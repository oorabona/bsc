child_process = require 'child_process'
shell = require 'shelljs'
Q = require 'q'
util = require 'util'

logging = require './logging'
{Config} = require './config'
{toType,recursiveMerge} = require './utils'

# commands to copy from shelljs into globals.
ShellCommands = [
  "cat", "cd", "chmod", "cp", "dirs", "env", "exit", "find", "grep",
  "ls", "mkdir", "mv", "popd", "pushd", "pwd", "rm", "sed", "test", "which"
]

Dispatch =
  run_exec: (command, settings) ->
    logging.info "+ #{command}"
    matches = command.match Config.REPLACE_SETTING_RE

    if matches
      matches.forEach (settingToReplace) ->
        # Remove leading '%'
        lookupSetting = settingToReplace[1...]
        unless settingValue = settings[lookupSetting]
          throw new Error "Setting '#{lookupSetting}' not found for command '#{command}!'"

        if 'array' is toType settingValue
          settingValue = settingValue.join ' '

        command = command.replace settingToReplace, settingValue

    # Make a new promise
    deferred = Q.defer()
    promise = deferred.promise

    # If first argument is one of the ShellCommands list, use shelljs instead.
    argv = command.split(' ')
    if ShellCommands.indexOf(argv[0]) isnt -1
      shellCode = shell[argv[0]].apply @, argv[1...]
      logging.debug "shell command '#{command}' returned '#{shellCode}'"
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

  run_env: (command, settings) ->
    return

module.exports = Dispatch
