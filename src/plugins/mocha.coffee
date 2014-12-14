###
Mocha plugin for UBS

It adds just two settings by default:
settings:
  mocha:
    bin: './node_modules/.bin/mocha'
    opts: ''

###

module.exports =
  Settings:
    mocha:
      bin: './node_modules/.bin/mocha'
      opts: ''

  Rules:
    """
    mocha-test:
      - mocha -R %mocha.display
    """

module.exports.run_mocha = (mocha) ->
  console.log "run_mocha #{mocha}"
  return
