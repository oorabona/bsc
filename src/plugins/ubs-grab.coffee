###
UBS plugin 'grab'
-----------------
Purpose: to grab a file from somewhere remote
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

    # Init a new promise, promise me a responseCode sometime
    deferred = Q.defer()
    {promise} = deferred
    responseCode = null

    outputStream = fs.createWriteStream path.join resolvedPath, path.basename command
    outputStream.on 'end', ->
      deferred.resolve responseCode

    request.get(command)
      .on 'error', (error) ->
        deferred.reject error
      .on 'response', (response) ->
        logging.debug "Grab server response: #{util.inspect response}"
        {statusCode} = response
        logging.info "+ Grab server response statusCode: #{statusCode}."
      .pipe outputStream

    promise
