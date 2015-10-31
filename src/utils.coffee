{Config} = require './config'
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
      if not object[key]? or typeof val isnt "object"
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

setAttribute = (from, key, value) ->
  if typeof from isnt 'object' or typeof key isnt 'string'
    throw new TypeError "setAttribute(from: Object, key: String, value: *), got (#{typeof from}, #{typeof what})"

  o = from
  w = key.replace /\[(\w+)\]/g, '.$1'  # convert indexes to properties
  w = w.replace /^\./, ''               # strip the leading dot
  a = w.split '.'
  {length} = a

  for k,i in a
    if i < length - 1
      if typeof o[k] isnt 'undefined'
        o = o[k]
      else
        o[k] = if /[0-9]+/.test a[i+1] then [] else {}
        o = o[k]
    else o[k] = value

  from

omit = (obj, elements) ->
  if typeof obj isnt 'object'
    throw new TypeError 'omit(Object, [elements to omit])'

  if typeof elements is 'string'
    e = [ elements ]
  else e = elements

  ret = {}
  ret[k] = v if k not in e for k,v of obj
  ret

parseCommand = (command, settings, callback) ->
  # Automagically set identity callback if none/falsy provided.
  if typeof callback isnt 'function'
    callback = (v) -> v

  matches = command.match Config.REPLACE_SETTING_RE

  if matches
    matches.forEach (settingToReplace) ->
      # Remove leading and trailing '%'
      lookupSetting = settingToReplace[1...-1]

      # See what we have in our dictionary and let the calling function be notified.
      # Callback can update settingValue if needed.
      settingValue = callback resolve settings, lookupSetting

      if settingValue
        logging.debug "Found token to lookup #{lookupSetting}: #{settingValue}"
      else
        throw new Error "Setting '#{lookupSetting}' not found for command '#{command}!'"

      command = command.replace settingToReplace, settingValue

  command

# Adapted from https://stackoverflow.com/questions/586182/how-do-i-insert-an-item-into-an-array-at-a-specific-index
# What:
#   inserts arguments 'sources' flattened if type is Array at specific index in dest array
# Syntax:
#   insertInArray(dest, index, value1, value2, ..., valueN)
insertInArray = (dest, index, sources...) ->
  index = Math.min index, dest.length
  arguments.length > 2 and dest.splice.apply dest, [index, 0].concat [].pop.call(sources)
  dest

module.exports = exports = {
  toType: toType
  recursiveMerge: recursiveMerge
  extend: deepExtend
  resolve: resolve
  parseCommand: parseCommand
  omit: omit
  insertInArray: insertInArray
  setAttribute: setAttribute
}
