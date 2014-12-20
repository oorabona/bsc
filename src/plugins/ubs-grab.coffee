###
UBS plugin 'grab'
-----------------

Purpose: add a handler to HTTP get a file
###

request = require 'request'
util = require 'util'
path = require 'path'
fs = require 'fs'
Q = require 'q'

@settings =
  grabTmpDir: '.'

@actions = (logging, config) ->
  grab: (command, settings) ->
    # check grabTmpDir is correct and does exist
    resolvedPath = path.resolve settings.grabTmpDir
    unless fs.existsSync resolvedPath
      throw new Error "Path #{settings.grabTmpDir} does not exist!"

    matches = command.match config.REPLACE_SETTING_RE

    if matches
      matches.forEach (settingToReplace) ->
        # Remove leading '%'
        lookupSetting = settingToReplace[1...]
        unless settingValue = settings[lookupSetting]
          throw new Error "Setting '#{lookupSetting}' not found for command '#{command}!'"

        if settingValue instanceof Array
          settingValue = settingValue.join ' '

        command = command.replace settingToReplace, settingValue

    logging.info "+ Grab #{command} (destination: #{resolvedPath})"

    # Make a new promise
    deferred = Q.defer()
    promise = deferred.promise

    request command
    .pipe fs.createWriteStream path.join resolvedPath, path.basename command
    .on 'error', (error) ->
      deferred.reject error
    .on 'end', (response) ->
      deferred.resolve response.status

    promise
