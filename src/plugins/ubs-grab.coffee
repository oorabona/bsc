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

@actions = (logging, config, helpers) ->
  grab: (command, settings) ->
    # check grabTmpDir is correct and does exist
    resolvedPath = path.resolve settings.grabTmpDir
    unless fs.existsSync resolvedPath
      throw new Error "Path #{settings.grabTmpDir} does not exist!"

    command = helpers.parseCommand command, settings

    logging.info "+ Grab #{command} (destination: #{resolvedPath})"

    # Init a new promise, promise me a statusCode sometime
    deferred = Q.defer()
    {promise} = deferred
    statusCode = null

    outputStream = fs.createWriteStream path.join resolvedPath, path.basename command
    outputStream.on 'finish', ->
      deferred.resolve statusCode

    request.get(command)
      .on 'error', (error) ->
        deferred.reject error
      .on 'response', (response) ->
        logging.debug "Grab server response: #{util.inspect response}"
        {statusCode} = response
        logging.info "+ Grab server response statusCode: #{statusCode}."
      .pipe outputStream

    promise
