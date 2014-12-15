coffee = require 'coffee-script'
fs = require 'fs'
Q = require 'q'
path = require 'path'
util = require 'util'
sandbox = require 'sandbox-runner'
yaml = require 'js-yaml'
_ = require 'underscore'

# breaking change in coffee-script 1.7
require 'coffee-script/register'

logging = require("./logging")
{toType,recursiveMerge} = require './utils'

plugins = {}
pluginPaths = []

buildPluginPaths = ->
  home = process.env["HOME"] or process.env["USERPROFILE"]
  pluginPaths = [
    "#{home}/.ubs/plugins"
    "#{process.cwd()}/.ubs/plugins"
  ]
  if process.env["UBS_PATH"]? then pluginPaths.push process.env["UBS_PATH"]
  pluginPaths = pluginPaths.map (folder) -> path.resolve(folder)

buildPluginPaths()

Plugins =
  loaded: {}
  getPaths: -> pluginPaths
  addPath: (path) ->
    if fs.lstatSync(path).isDirectory()
      pluginPaths.push path
    else
      throw new Error "#{path} is not a path to load plugins from!"
    return
  ###
  find plugin:
    @params
      - pluginName: String
    @desc
      Searches in all plugin paths a file with these patterns
      - ubs-pluginName.[coffee|js|yaml]
      - ubs-pluginName/index.[coffee|js|yaml]
    @return
      - filename to load
  ###
  find: (pluginName) ->
    for p in pluginPaths
      for ext in [ "coffee", "js", "yaml" ]
        for filename in [ "#{p}/ubs-#{pluginName}.#{ext}", "#{p}/ubs-#{pluginName}/index.#{ext}" ]
          if fs.existsSync(filename) then return filename
    return "ubs-#{pluginName}"
  load: (pluginName, context) ->
    logging.debug "Trying to load #{pluginName}"
    foundPlugin = @find pluginName
    logging.debug "Plugin found: #{foundPlugin}"
    # check extension and try to eval
    ext = foundPlugin.split('.').pop()

    Q.Promise (resolve, reject, notify) ->
      fs.readFile foundPlugin, "utf-8", (error, code) ->
        reject(new Error error) if error

        pContext = switch ext
          when 'coffee'
            logging.debug "Loading coffee file"
            sandbox.run coffee.compile code.toString(), bare: true
          when 'js'
            logging.debug "Loading JS file"
            sandbox.run coffee.compile code.toString(), bare: true
          when 'yaml'
            logging.debug "Loading YAML file"
            yaml.safeLoad code, yaml.JSON_SCHEMA
          else
            reject "Something went wrong very badly when trying to load #{pluginName}, #{ext} not found!"

        if pContext.settings
          settings = if typeof pContext.settings is 'function'
            pContext.settings()
          else pContext.settings or {}
          recursiveMerge context.settings, settings, false
        if pContext.rules
          rules = if typeof pContext.rules is 'function'
            pContext.rules context.settings
          else pContext.rules or {}

          if 'string' is toType rules
            rules = yaml.safeLoad rules, yaml.JSON_SCHEMA

          # Make sure settings is not overwritten by rules.
          recursiveMerge context, _.omit(rules, 'settings'), false

        resolve context

module.exports = Plugins
