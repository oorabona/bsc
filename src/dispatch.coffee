child_process = require 'child_process'
shell = require 'shelljs'
Q = require 'q'
util = require 'util'

logging = require './logging'
{toType,recursiveMerge} = require './utils'

REPLACE_SETTING_RE = /\%(\w[-\.\w]*)/g

# commands to copy from shelljs into globals.
ShellCommands = [
  "cat", "cd", "chmod", "cp", "dirs", "echo", "env", "exit", "find", "grep",
  "ls", "mkdir", "mv", "popd", "pushd", "pwd", "rm", "sed", "test", "which"
]

Dispatch =
  run_exec: (command, settings) ->
    logging.info "+ #{command}"
    matches = command.match REPLACE_SETTING_RE

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
        throw new Error "Command '#{command}' returned '#{err}'"
      deferred.resolve shellCode ? 'success'
    else
      # i bet this doesn't work on windows.
      command = [ "/bin/sh", "-c", command ]
      if not settings.env? then settings.env = process.env
      if not settings.cwd? then settings.cwd = process.cwd()
      if not settings.stdio? then settings.stdio = "inherit"

      p = child_process.spawn command[0], command[1...], settings
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

module.exports = Dispatch
