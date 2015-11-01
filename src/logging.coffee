# Logging
# =======
# Handles basic logging with colors.. or not!

sprintf = require 'sprintf'
strftime = require 'strftime'
Config = require './config'

appStartTime = Date.now()

inColor = (color, text) ->
  if Config.usingColors
    "\u001b[#{Config.colors[color]}m#{text}\u001b[0m"
  else
    text

error = (text) -> console.error inColor("red", "ERROR: " + text)
warning = (text) -> console.log inColor("orange", "Warning: " + text)
notice = (text) -> console.log inColor("yellow", text)
taskinfo = (text) -> if Config.isVerbose or Config.isDebug then console.log inColor("cyan", text)
info = (text) -> if Config.isVerbose or Config.isDebug then console.log inColor("green", text)
debug = (text) ->
  if not Config.isDebug then return
  now = (Date.now() - appStartTime) / 1000.0
  console.log inColor("purple", sprintf.sprintf "[%06.3f] %s", now, text)
mark = ->
  console.log inColor("yellow", "--- MARK --- ") + inColor("brightCyan", strftime("%H:%M:%S [%d-%b-%Y]"))

exports.inColor = inColor
exports.error = error
exports.warning = warning
exports.notice = notice
exports.taskinfo = taskinfo
exports.info = info
exports.debug = debug
exports.mark = mark
