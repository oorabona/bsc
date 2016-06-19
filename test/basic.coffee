###
Run the binary and check results returned by example build.yml test cases
###

expect = require 'expect.js'
{exec, done} = require 'mocha-sprinkles'

Q = require 'q'
fs = require 'fs'

binubs = "#{process.cwd()}/bin/ubs"

describe 'Bootstrap tests', ->
  it "responds to --help", (done) ->
    exec("#{binubs} --help").then (p) ->
      stdout = p.stdout.toString()
      expect(p.stderr.toString()).to.be ''
      expect(stdout).to.match /usage:/
      expect(stdout).to.match /options:/
      done()
    , done

  it 'should error if build file is not found', (done) ->
    exec("#{binubs} -b test/notfound.yml").then (p) ->
      done new Error "Should not be here!"
    , (p) ->
      expect(p.stderr.toString()).to.match /ENOENT/
      done()

  it 'should be able to output log messages', (done) ->
    exec("#{binubs} -b test/helloworld.yml test").then (p) ->
      stdout = p.stdout.toString()
      expect(p.stderr.toString()).to.be 'WARN: warning level\nERROR: error level\n'
      expect(stdout).to.match /Hello World!/
      expect(stdout).to.match /Done\./
      expect(stdout).to.not.match /Bam!/
      done()
    , done

  it 'should be able to get and set environment variables', (done) ->
    exec("#{binubs} -b test/test_env.yml test").then (p) ->
      stdout = p.stdout.toString()
      expect(stdout).to.match /after\: works!/
      expect(stdout).to.match /composite\: still works!/
      expect(stdout).to.match /Done\./
      done()
    , done

  # Call another instance of ourselves from build script to ensure we correctly
  # propagate environment variables both ways (parent -> child and child->parent).
  it 'should be able to run nested instance and back propagate status', (done, error) ->
    exec("#{binubs} -b test/test_ipc_child.yml test").then (p) ->
      expect(p.stdout.toString()).to.match /Expecting test to be working!/
      done()
    , error

  # Detect platform and `exec` conditionally commands
  it 'should be able to detect host platform and run conditionally', (done, error) ->
    exec("#{binubs} -b test/test_host_platform.yml test").then (p) ->
      stdout = p.stdout.toString()
      regexp = /Apple\./
      expect(stdout).to.match new RegExp "#{process.platform}",'i'
      expect(stdout).to.match new RegExp "=#{process.platform}=",'i'
      if process.platform is 'darwin'
        expect(stdout).to.not.match regexp
      else
        expect(stdout).to.match regexp
      done()
    , error

describe 'Internal tests', ->
  it 'should be able to run ShellJS commands without error', (done, error) ->
    exec("#{binubs} -b test/test_internal_shell.yml all").then (p) ->
      expect(p.stdout.toString()).to.match /All tests passed/
      done()
    , error

  it 'must respect variable override precedence', (done, error) ->
    exec("UBS_OPTS=-D #{binubs} -b test/test_change_shell.yml test exec.linux.shellArgs='-c' exec.win32.shellArgs='/c'").then (p) ->
      stdout = p.stdout.toString()
      expect(stdout).to.match /--debug/
      expect(stdout).to.not.match /shellArgs.*[x|start]$/
      done()
    , error

describe 'Plugins', ->
  describe 'Package JSON', ->
    it 'should be able to output version from packagejson', (done, error) ->
      exec("#{binubs} -b test/test_plugin_packagejson.yml test").then (p) ->
        stdout = p.stdout.toString()
        expect(stdout).to.match /version [0-9]+\.[0-9]+/
        expect(stdout).to.match /Done\./
        done()
      , error

  describe 'Grab', ->
    it 'should be able to retrieve this package\'s master zip file', (done, error) ->
      exec("#{binubs} -v -b test/test_plugin_grab.yml grab").then (p) ->
        stdout = p.stdout.toString()
        expect(stdout).to.match /Retrieving/
        expect(stdout).to.match /Done\./
        done()
      , error

  after ->
    # We completed our task, remove created files
    fs.unlinkSync 'test/master.zip'
