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
mkdirp = require 'mkdirp'

@actions = (logging, config, helpers) ->
  grab: (command, settings) ->
    # Parse input, if a string, like:
    # - grab: "%remoteUrl% %localTarget%"
    # Then input is parsed as is and split after
    # If input is an object, as in:
    # - grab: remoteUrl: "%remoteUrl%", localTarget: "%localTarget%"
    # Then input is parsed and no need to split
    if 'string' is helpers.toType command
      toGrab = helpers.parseCommand command, settings, (settingValue) ->
        if 'array' is helpers.toType settingValue
          settingValue.join ' '
        else settingValue
    else
      toGrab = helpers.parseCommand [ command['remoteUrl'], command['localTarget'] ], settings

    switch helpers.toType toGrab
      when 'array'
        cmdArray = toGrab
      when 'string'
        cmdArray = toGrab.split ' '
      else
        throw new Error "Bad invocation of grab: expected String or Array, got #{helpers.toType toGrab}!"

    switch cmdArray.length
      when 1
        remoteUrl = cmdArray[0]
        localTarget = '.'
      when 2
        remoteUrl = cmdArray[0]
        localTarget = cmdArray[1]
      else
        throw new Error "Bad invocation of grab: expected (remoteUrl:String, localTarget:String), got  #{util.inspect cmdArray}"

    # Ok sanity checks done, populate variables
    for arg in cmdArray
      command = helpers.parseCommand arg, settings

    # We might have either a file name or just a path. In the latter case, we reuse the file input name.
    resolvedTarget = path.resolve localTarget
    resolvedPath = path.dirname resolvedTarget

    try
      if fs.lstatSync(resolvedTarget).isDirectory()
        resolvedFileName = path.basename remoteUrl
        resolvedPath = resolvedTarget
      else
        resolvedFileName = path.basename resolvedTarget
    catch error
      if fs.lstatSync(resolvedPath).isDirectory()
        resolvedFileName = path.basename resolvedTarget

    logging.info "+ Grab: Retrieving #{remoteUrl} (destination: #{resolvedPath}, file: #{resolvedFileName})"

    # Init a new promise, promise me a statusCode sometime
    deferred = Q.defer()
    {promise} = deferred
    statusCode = null

    outputStream = fs.createWriteStream path.join resolvedPath, resolvedFileName
    outputStream.on 'finish', ->
      deferred.resolve statusCode

    request.get(remoteUrl)
      .on 'error', (error) ->
        deferred.reject error
      .on 'response', (response) ->
        logging.debug "+ Grab: server response: #{util.inspect response}"
        {statusCode} = response
        logging.info "+ Grab: server response statusCode: #{statusCode}."
      .pipe outputStream

    promise
