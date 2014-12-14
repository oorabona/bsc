logging = require './logging'
fs = require 'fs'
path = require 'path'
yaml = require 'js-yaml'

VERSION = "0.0.1"

Config =
  DEFAULT_RULES_FILE: 'rules.coffee'
  DEFAULT_BUILD_FILE: 'build.yml'
  monitor: (value) ->
    if value? then @_monitor = value
    @_monitor

  version: -> VERSION

  # for tests
  reset: ->
    @_monitor = true

  # builin rules
  builtinRules: ->
    yaml.safeLoad """
      settings: &settings
        toClean: ['lib']
        toDistclean: ['node_modules']

      clean:
        - exec: rm -rf %toClean

      distclean:
        - task: clean
        - exec: rm -rf %toDistclean
      """

Config.reset()

exports.Config = Config
exports.VERSION = VERSION
