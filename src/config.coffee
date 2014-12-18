logging = require './logging'
fs = require 'fs'
path = require 'path'

Config =
  SETTING_RE: /^(\w[-\.\w]*)=(.*)$/
  TASK_REGEX: /^[a-z][-a-z0-9_]*$/
  DEFAULT_TASK: 'install'

  REPLACE_SETTING_RE: /\%(\w[-\.\w]*)/g

  DEFAULT_BUILD_FILE: 'build.yml'
  monitor: (value) ->
    if value? then @_monitor = value
    @_monitor

  # for tests
  reset: ->
    @_monitor = true

Config.reset()

exports.Config = Config
