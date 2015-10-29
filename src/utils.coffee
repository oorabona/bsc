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

module.exports = exports = {
  toType: toType
  recursiveMerge: recursiveMerge
  extend: deepExtend
}
