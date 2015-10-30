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
  w = w.replace /^\./, ''               # strip a leading dot
  a = w.split '.'
  for k in a
    if typeof o[k] isnt 'undefined'
      o = o[k]
    else
      return

  o

omit = (obj, elements) ->
  if typeof obj isnt 'object'
    throw new TypeError 'omit(Object, [elements to omit])'

  if typeof elements is 'string'
    e = [ elements ]
  else e = elements

  ret = {}
  ret[k] = v if k not in e for k,v of obj
  ret

parseCommand = (command, callback) ->
  matches = command.match Config.REPLACE_SETTING_RE

  # Automagically set default callback if none/falsy provided.
  if typeof callback isnt 'function'
    callback = (v) -> v

  if matches
    matches.forEach (settingToReplace) ->
      # Remove leading and trailing '%'
      lookupSetting = settingToReplace[1...-1]

      # Let the calling function by notified and update settingValue if needed.
      settingValue = callback lookupSetting

      if settingValue
        logging.debug "Found token to lookup #{lookupSetting}: #{settingValue}"
      else
        throw new Error "Setting '#{lookupSetting}' not found for command '#{command}!'"

      command = command.replace settingToReplace, settingValue

  command

module.exports = exports = {
  toType: toType
  recursiveMerge: recursiveMerge
  extend: deepExtend
  resolve: resolve
  parseCommand: parseCommand
  omit: omit
}
