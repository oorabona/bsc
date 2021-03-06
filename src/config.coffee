# Config variables

fs = require 'fs'
path = require 'path'

module.exports = exports =
  default_settings:
    colors:
      error: 'red'
      warning: 'orange'
      notice: 'yellow'
      taskinfo: 'cyan'
      info: 'green'
      debug: 'purple'
    exec:
      win32:
        shellCmd: 'cmd.exe'
        shellArgs: '/c'
      linux:
        shellCmd: '/bin/sh'
        shellArgs: '-c'
      darwin:
        shellCmd: '/bin/sh'
        shellArgs: '-c'
      freebsd:
        shellCmd: '/bin/sh'
        shellArgs: '-c'
      sunos:
        shellCmd: '/bin/sh'
        shellArgs: '-c'

  SETTING_RE: /^(.*)=(.*)$/
  TASK_REGEX: /^[a-z][-a-z0-9_]*$/
  DEFAULT_TASK: 'install'

  REPLACE_SETTING_RE: /\%(\w[\[\]\:\-\.\w]*)\%/g

  DEFAULT_BUILD_FILE: 'build.yml'

  colors:
    yellow: "38;5;11"
    orange: "33"
    red: "31"
    purple: "35"
    blue: "34"
    brightBlue: "38;5;12"
    brightCyan: "38;5;14"
    cyan: "36"
    green: "32"
    black: "30"
    gray: "37"
    white: "38;5;15"
    off: "0"

  usingColors: process.stdout.isTTY
  useColors: (bool) ->
    if bool? then @usingColors = bool
    @usingColors

  isVerbose: false
  setVerbose: (bool) ->
    if bool?
      @isVerbose = bool
      if not bool then @isDebug = false
    @isVerbose

  isDebug: false
  setDebug: (bool) ->
    if bool?
      @isDebug = bool
      if bool then @isVerbose = true
    @isDebug
