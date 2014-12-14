coffee = require 'coffee-script'
fs = require 'fs'
Module = require 'module'
path = require 'path'
util = require 'util'
vm = require 'vm'

# breaking change in coffee-script 1.7
require 'coffee-script/register'

logging = require("./logging")

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
  load: (pluginName) ->
    console.log "trying to load #{pluginName}"
    return
  
module.exports = Plugins
