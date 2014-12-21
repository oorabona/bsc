###
Run the binary and check results returned by example build.yml test cases
###

expect = require 'expect.js'
mocha_sprinkles = require 'mocha-sprinkles'

Q = require 'q'
fs = require 'fs'

exec = mocha_sprinkles.exec
future = mocha_sprinkles.future

binubs = "#{process.cwd()}/bin/ubs"

describe 'Bootstrap tests', ->
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

  it 'should be able to output log messages', future ->
    exec("#{binubs} -b test/helloworld.yml test").then (p) ->
      expect(p.stderr.toString()).to.be("ERROR: error level\n")
      expect(p.stdout.toString()).to.match /Hello World!/

  it 'should be able to get and set environment variables', future ->
    exec("#{binubs} -b test/test_env.yml test", env: WTF: "works!").then (p) ->
      expect(p.stdout.toString()).to.match /bbq still works!/

describe 'Plugins', ->
  describe 'Package JSON', ->
    it 'should be able to output version from packagejson', future ->
      exec("#{binubs} -b test/test_plugin_packagejson.yml test").then (p) ->
        expect(p.stdout.toString()).to.match /version [0-9]+\.[0-9]+/

  describe 'Grab', ->
    it 'should be able to retrieve this package\'s master zip file', future ->
      exec("#{binubs} -b test/test_plugin_grab.yml test").then (p) ->
        expect(p.stdout.toString()).to.match /Retrieving/
        expect(fs.existsSync 'test/master.zip').to.be.ok()
