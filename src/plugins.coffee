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

logging = require "./logging"
Utils = require './utils'
Dispatch = require "./dispatch"
{Config} = require './config'

plugins = {}
pluginPaths = []

buildPluginPaths = ->
  home = process.env["HOME"] or process.env["USERPROFILE"]
  pluginPaths = [
    "#{home}/.ubs/plugins"
    "#{process.cwd()}/.ubs/plugins"
    "#{__dirname}/plugins"
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
    logging.debug "Trying to load plugin '#{pluginName}'"
    foundPlugin = @find pluginName
    logging.debug "Plugin found: #{foundPlugin}"
    # check extension and try to eval
    ext = path.extname(foundPlugin)[1...]

    # If no ext, it might be an already installed npm module.
    unless ext
      try
        pContext = require foundPlugin
      catch e
        throw new Error "Could not find plugin '#{foundPlugin}' in NPM modules"

      # If we have something but seems empty, throw
      if pContext instanceof Object
        unless pContext.settings or pContext.rules
          throw new Error "Plugin empty or bad: #{pluginName} (#{foundPlugin})"

        if pContext.settings
          settings = if typeof pContext.settings is 'function'
            pContext.settings()
          else pContext.settings or {}
          Utils.recursiveMerge context.settings, settings, false
        if pContext.rules
          rules = if typeof pContext.rules is 'function'
            pContext.rules context.settings
          else pContext.rules or {}

          if 'string' is Utils.toType rules
            rules = yaml.safeLoad rules, yaml.JSON_SCHEMA

          # Make sure settings is not overwritten by rules.
          Utils.recursiveMerge context, _.omit(rules, 'settings'), false
        return Q context

    Q.Promise (resolve, reject, notify) ->
      fs.readFile foundPlugin, "utf8", (error, code) ->
        reject(new Error error) if error

        try
          pContext = switch ext
            when 'coffee'
              logging.debug "Loading coffee file #{foundPlugin}"
              sandbox.run coffee.compile code.toString(), bare: true
            when 'js'
              logging.debug "Loading JS file #{foundPlugin}"
              sandbox.run code.toString()
            when 'yaml'
              logging.debug "Loading YAML file #{foundPlugin}"
              pluginCtx = yaml.safeLoad code, yaml.JSON_SCHEMA
              resolve Utils.recursiveMerge context, pluginCtx
            else
              # No ext => let's try to 'require' it (might be an installed module)
              throw new Error "Could not load #{pluginName}: #{foundPlugin} not found!"

          if pContext.actions
            Dispatch.extend pContext.actions logging, Config, Utils
          if pContext.settings
            settings = if typeof pContext.settings is 'function'
              pContext.settings context.settings
            else pContext.settings or {}
            Utils.recursiveMerge context.settings, settings, false
          if pContext.rules
            rules = if typeof pContext.rules is 'function'
              pContext.rules context.settings
            else pContext.rules or {}

            if 'string' is Utils.toType rules
              rules = yaml.safeLoad rules, yaml.JSON_SCHEMA

            # Make sure settings is not overwritten by rules.
            Utils.recursiveMerge context, _.omit(rules, 'settings'), false

          resolve context
        catch e
          reject e

module.exports = Plugins
