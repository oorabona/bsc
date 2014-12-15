Utils =
# Kudos go to http://javascriptweblog.wordpress.com/2011/08/08/fixing-the-javascript-typeof-operator/
  toType: (obj) ->
    ({}).toString.call(obj).match(/\s([a-zA-Z]+)/)[1].toLowerCase()

  recursiveMerge: (obj1, obj2, force = true) ->
    for k, v of obj2
      if "array" is Utils.toType v
        obj1[k] or= []
        Utils.recursiveMerge obj1[k], v, force
      else if "object" is Utils.toType v
        obj1[k] or= {}
        Utils.recursiveMerge obj1[k], v, force
      else if typeof obj1[k] is "undefined" or force
        obj1[k] = v
    return obj1

module.exports = Utils
