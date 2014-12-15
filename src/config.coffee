logging = require './logging'
fs = require 'fs'
path = require 'path'

Config =
  DEFAULT_RULES_FILE: 'rules.coffee'
  DEFAULT_BUILD_FILE: 'build.yml'
  monitor: (value) ->
    if value? then @_monitor = value
    @_monitor

  # for tests
  reset: ->
    @_monitor = true

Config.reset()

exports.Config = Config
