###
Mocha plugin for UBS

This plugin enables you to run Mocha based tests, with support of Coffeescript
if needs be.

It is also a basic example on how to run an external command with variables,
mixing Coffee and YAML.
###

@settings =
  mocha:
    bin: './node_modules/.bin/mocha'
    options: ['--colors']
    display: 'spec'
    useCoffee: off
    grep: null

@rules = (settings) ->
  if settings.mocha.useCoffee is on
    settings.mocha.options.push "--compilers coffee:coffee-script/register"
  """
  mocha-test:
    - exec: #{settings.mocha.bin} -R #{settings.mocha.display} #{settings.mocha.options.join(' ')}
  """
