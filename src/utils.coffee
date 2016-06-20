# Some helpers utils
Config = require './config'
logging = require "./logging"

# Kudos go to http://javascriptweblog.wordpress.com/2011/08/08/fixing-the-javascript-typeof-operator/
toType = (obj) ->
  ({}).toString.call(obj).match(/\s([a-zA-Z]+)/)[1].toLowerCase()

recursiveMerge = (obj1, obj2, force = true) ->
  for k, v of obj2
    if "array" is toType v
      obj1[k] or= []
      recursiveMerge obj1[k], v, force
    else if "object" is toType v
      obj1[k] or= {}
      recursiveMerge obj1[k], v, force
    else if typeof obj1[k] is "undefined" or force
      obj1[k] = v
  return obj1

# http://zurb.com/forrst/posts/Deep_Extend_an_Object_in_CoffeeScript-DWu
deepExtend = (object, extenders...) ->
  return {} if not object?
  for other in extenders
    for own key, val of other
      if not object[key]? or typeof val isnt "object" or 'array' is toType val
        object[key] = val
      else
        object[key] = deepExtend object[key], val

  object

# Adapted from https://stackoverflow.com/questions/6491463/accessing-nested-javascript-objects-with-string-key
resolve = (from, what) ->
  if typeof from isnt 'object' or typeof what isnt 'string'
    throw new TypeError "resolve(from: Object, what: String), got (#{typeof from}, #{typeof what})"

  o = from
  w = what.replace /\[(\w+)\]/g, '.$1'  # convert indexes to properties
  w = w.replace /^\./, ''               # strip the leading dot
  a = w.split '.'
  for k in a
    if typeof o[k] isnt 'undefined'
      o = o[k]
    else
      return

  o

# Yep looks like the preious one, this time it sets value in object at position key.
setAttribute = (from, key, value) ->
  if typeof from isnt 'object' or typeof key isnt 'string'
    throw new TypeError "setAttribute(from: Object, key: String, value: *), got (#{typeof from}, #{typeof what})"

  o = from
  w = key.replace /\[(\w+)\]/g, '.$1'  # convert indexes to properties
  w = w.replace /^\./, ''               # strip the leading dot
  a = w.split '.'
  {length} = a

  # We process till before the last element because we might need to create the entry.
  # In that case we will decide whether we need to create an Array or an Object.
  # If we have a number, it must be an array.
  # Otherwise it will be considered as an Object property.
  for k,i in a
    if i < length - 1
      if typeof o[k] isnt 'undefined'
        o = o[k]
      else
        o[k] = if /[0-9]+/.test a[i+1] then [] else {}
        o = o[k]
    else o[k] = value

  from

# Quick way to implement _.omit in CoffeeScript!
omit = (obj, elements) ->
  if typeof obj isnt 'object' or typeof elements is 'undefined'
    throw new TypeError 'omit(Object, [elements to omit])'

  if typeof elements is 'string'
    e = [ elements ]
  else e = elements

  ret = {}
  ret[k] = v if k not in e for k,v of obj
  ret

# Process commands given to a plugin based on the settings.
# Callback is not mandatory unless you want to take care of extra handling of command.
parseCommand = (command, settings, callback) ->
  # Automagically set identity callback if none/falsy provided.
  if typeof callback isnt 'function'
    callback = (v) -> v

  if 'string' isnt typeof command and 'array' isnt toType command
    throw new Error "Bad invocation of parseCommand: (command: [String or Array], settings: Object, callback: Function)"

  # To preserve same type for caller, we will return a string if we were given
  # a string and an array for an array.
  if 'string' is typeof command
    isString = true
    commands = [ command ]
  else
    isString = false
    commands = command

  results = commands.map (command) ->
    matches = command.match Config.REPLACE_SETTING_RE

    if matches
      matches.forEach (settingToReplace) ->
        # Remove leading and trailing '%'
        lookupSetting = settingToReplace[1...-1]

        # Split command in left and right with separator ':'
        matches = lookupSetting.split ':'
        if matches.length > 1
          variableName = matches[0]
          options = matches[1]
          separator = matches[2]
          # If we have non falsy options, we look which one
          resolvedVariable = resolve settings, variableName
          if !!options
            switch options
              when 'q'  # quotes
                enclose = '\''
              when 'dq' # double quotes
                enclose = '\"'
              else
                throw new Error "Could not interpret #{options} in #{settingToReplace}"
          else enclose = ''
          if !!separator
            switch separator
              when 'cm'  # comma
                separator = ','
              when 'cln' # colon
                separator = ':'
              when 'sc'  # semi colon
                separator = ';'
              else
                throw new Error "Could not interpret #{separator} in #{settingToReplace}"
          else separator = ''

          if 'array' is toType resolvedVariable
            resolvedVariable = resolvedVariable.map (el,index) ->
              if index < resolvedVariable.length - 1
                sep = separator
              else sep = ''
              "\\#{enclose}#{el}\\#{enclose}#{sep}"
          else
            resolvedVariable = "\\#{enclose}#{resolvedVariable}\\#{enclose}"
        else
          resolvedVariable = resolve settings, lookupSetting

        # See what we have in our dictionary and let the calling function be notified.
        # Callback can update settingValue if needed.
        settingValue = callback resolvedVariable

        if settingValue
          logging.debug "Found token to lookup #{lookupSetting}: #{settingValue}"
        else
          throw new Error "Setting '#{lookupSetting}' not found for command '#{command}!'"

        command = command.replace settingToReplace, settingValue

    command

  if isString then results[0] else results

# Adapted from https://stackoverflow.com/questions/586182/how-do-i-insert-an-item-into-an-array-at-a-specific-index
# What:
#   inserts arguments 'sources' flattened if type is Array at specific index in dest array
# Syntax:
#   insertInArray(dest, index, value1, value2, ..., valueN)
insertInArray = (dest, index, sources...) ->
  index = Math.min index, dest.length
  arguments.length > 2 and dest.splice.apply dest, [index, 0].concat [].pop.call(sources)
  dest

defaults = (src, ref) ->
  for own k,v of ref
    if typeof src[k] is 'undefined'
      src[k] = v

  src

# https://stackoverflow.com/questions/11060631/how-do-i-clone-copy-an-instance-of-an-object-in-coffeescript
clone = (obj) ->
  return obj  if obj is null or typeof (obj) isnt "object"
  temp = new obj.constructor()
  for key of obj
    temp[key] = clone(obj[key])
  temp

module.exports = exports = {
  clone: clone
  defaults: defaults
  toType: toType
  recursiveMerge: recursiveMerge
  extend: deepExtend
  resolve: resolve
  parseCommand: parseCommand
  omit: omit
  insertInArray: insertInArray
  setAttribute: setAttribute
}
