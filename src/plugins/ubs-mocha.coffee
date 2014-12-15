###
Mocha plugin for UBS

It adds just two settings by default:
settings:
  mocha:
    bin: './node_modules/.bin/mocha'
    opts: ''

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
