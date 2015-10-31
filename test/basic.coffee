###
Run the binary and check results returned by example build.yml test cases
###

expect = require 'expect.js'
mocha_sprinkles = require 'mocha-sprinkles'

Q = require 'q'
fs = require 'fs'

exec = mocha_sprinkles.exec
done = mocha_sprinkles.done

binubs = "#{process.cwd()}/bin/ubs"

describe 'Bootstrap tests', ->
  it "responds to --help", (done) ->
    exec("#{binubs} --help").then (p) ->
      expect(p.stderr.toString()).to.be("")
      expect(p.stdout.toString()).to.match /usage:/
      expect(p.stdout.toString()).to.match /options:/
      done()

  it 'should error if build file is not found', (done) ->
    exec("#{binubs} -b test/notfound.yml").then (p) ->
      done new Error "Should not be here!"
    , (p) ->
      expect(p.stderr.toString()).to.match /ENOENT/
      done()

  it 'should be able to output log messages', (done) ->
    exec("#{binubs} -b test/helloworld.yml test").then (p) ->
      expect(p.stderr.toString()).to.be("ERROR: error level\n")
      expect(p.stdout.toString()).to.match /Hello World!/
      expect(p.stdout.toString()).to.match /Done\./
      expect(p.stdout.toString()).to.not.match /Bam!/
      done()

  it 'should be able to get and set environment variables', (done) ->
    exec("#{binubs} -b test/test_env.yml test", env: WTF: "works!").then (p) ->
      expect(p.stdout.toString()).to.match /bbq still works!/
      expect(p.stdout.toString()).to.match /Done\./
      done()

  # Call another instance of ourselves from build script to ensure we correctly
  # propagate environment variables both ways (parent -> child and child->parent).
  # We also override settings from command line to specify ubs instead of setting
  # "_" environment variable which might not be possible under some testing environments.
  it 'should be able to run nested instance and back propagate status', (done) ->
    exec("#{binubs} -b test/test_ipc_child.yml test bin=#{binubs}").then (p) ->
      expect(p.stdout.toString()).to.match /Expecting test to be working!/
      done()

describe 'Plugins', ->
  describe 'Package JSON', ->
    it 'should be able to output version from packagejson', (done) ->
      exec("#{binubs} -b test/test_plugin_packagejson.yml test").then (p) ->
        expect(p.stdout.toString()).to.match /version [0-9]+\.[0-9]+/
        expect(p.stdout.toString()).to.match /Done\./
        done()

  describe 'Grab', ->
    it 'should be able to retrieve this package\'s master zip file', (done) ->
      exec("#{binubs} -v -b test/test_plugin_grab.yml test").then (p) ->
        expect(p.stdout.toString()).to.match /Retrieving/
        expect(p.stdout.toString()).to.match /statusCode:\ 200\./
        expect(p.stdout.toString()).to.match /Done\./
        expect(fs.existsSync 'test/master.zip').to.be.ok()
        done()

  after ->
    # We completed our task, remove created files
    fs.unlinkSync "test/master.zip"
