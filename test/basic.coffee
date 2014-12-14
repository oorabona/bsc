###
Run the binary and make sure example build provide expected results
###

expect = require 'expect.js'
mocha_sprinkles = require 'mocha-sprinkles'

Q = require 'q'

exec = mocha_sprinkles.exec
future = mocha_sprinkles.future

binubs = "#{process.cwd()}/bin/ubs"

describe 'UBS', ->
  it "responds to --help", future ->
    exec("#{binubs} --help").then (p) ->
      expect(p.stderr.toString()).to.be("")
      expect(p.stdout.toString()).to.match /usage:/
      expect(p.stdout.toString()).to.match /options:/

  it 'should error if build file is not found', future ->
    exec("#{binubs} -b test/notfound.yml").then (p) ->
      done "Should not be here!"
    , (p) ->
      expect(p.stderr.toString()).to.match /ENOENT/

  it 'should display "Hello World!"', future ->
    exec("#{binubs} -b test/helloworld.yml test").then (p) ->
      expect(p.stderr.toString()).to.be("")
      expect(p.stdout.toString()).to.match /Hello World!/
