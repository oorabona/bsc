# Logging
# =======
# Handles basic logging with colors.. or not!

{sprintf} = require 'sprintf'
Config = require './config'

appStartTime = Date.now()

inColor = (color, text) ->
  if Config.usingColors
    "\u001b[#{Config.colors[color]}m#{text}\u001b[0m"
  else
    text

module.exports = exports =
  error: (text, color='red') -> console.error inColor color, "ERROR: #{text}"
  warning: (text, color='orange') -> console.warn inColor color, "WARN: #{text}"
  notice: (text, color='yellow') -> console.log inColor color, text
  taskinfo: (text, color='cyan') -> if Config.isVerbose or Config.isDebug then console.log inColor color, text
  info: (text, color='green') -> if Config.isVerbose or Config.isDebug then console.info inColor color, text
  debug: (text, color='purple') ->
    return unless Config.isDebug
    now = (Date.now() - appStartTime) / 1000.0
    console.log inColor color, sprintf "[%06.3f] %s", now, text
