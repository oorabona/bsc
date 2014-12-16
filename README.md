# Unified Build System

This package has been greatly inspired by what is generally used for NodeJS
projects.

But whether [Grunt](http://gruntjs.com) or [Cake](http://www.coffeescript.org)
were not really convincing: so much more code to write !

A very different design pattern is used in @robey [plz](https://github.com/robey/plz).
It gave a lot of ideas you can find in this code and was a great code base !

So why _Unified_ ? Well, it has been designed from other projects pros and cons. Unified also by the choice of YAML from [Travis CI](http://travis-ci.org) ```.travis.yml``` and an old experience of ```Makefile```!

## How it works

You need a ```build.yml``` in your __current working directory__ and that's it.

```shell
$ ubs
```

By default, __ubs__ will look for a target named 'install'.
But you can select your targets:

```shell
$ ubs clean install
```

Targets will be run in sequence and depending tasks will be automatically added.

```shell
$ ubs --help
ubs 0.2.5
usage: ubs [options] [task-setting]* [task-name]*
general options are listed below. task-settings are all of the form
"<name>=<value>".
example:
  ubs -b build.yml build debug=true test
  loads build from build.yml, adds { debug: "true" } to the
  global settings object, then runs task "build" followed by task "test".
options:
  --buildfile FILENAME (-b)
      use a specific rules file (default: build.yml)
  --tasks (-t)
      show the list of tasks and their descriptions
  --watch (-w)
      keep running (until killed), watching for changed files
  --help
      this help
  --version
      show the version string and exit
  --verbose (-v)
      log more about what it's doing
  --debug (-D)
      log quite a lot more about what it's thinking
  --colors / --no-colors
      override the color detection to turn on/off terminal colors
```

> ##Note:
> At the moment _watch_ is not supported, see [TODO](#TODO)

## The build.yml

The build file is all [YAML](http://yaml.org) and follows a pattern close to
Makefile.

```yaml
# The init part, checked first and looks for plugins to load (in order, but order
# in this example does not really matter).
init:
  plugins:
    - mocha
    - packagejson
    - clean
# It is the place to set environment variables. Plugins can add extra key=value
# settings, as for Mocha where 'bin' and 'useCoffe'. Mocha options are modified
# by useCoffee then propagated when called.
# 'clean' plugin adds settings and clean tasks for us. No need to modify them here :)
settings:
  srcPath: 'src'
  libPath: 'lib'
  mocha:
    bin: 'mocha'
    useCoffee: true
prebuild:
  - npm update
# Note that you can call shell commands
# %name and %version are variables from settings above. They are string replaced
# before running command.
build:
  - echo Building %name version %version ...
  - coffee -o %libPath -c %srcPath/*.coffee
# Sometimes you rely on other tasks, so that is the way you call them.
# Here mocha-test is a rule created by the 'mocha' plugin
test:
  - task: build
  - task: mocha-test
# You see below a quite complete list of what you can actually achieve with UBS.
# Stay tuned !
install:
  - task: build
  - echo Moving plugins to lib/plugins folder
  - mkdir %libPath/plugins
  - cp %srcPath/plugins/* %libPath/plugins/
  - echo Installation complete, you can 'cd %libPath'
```

As you can see, each sequence is either a command to execute, this is the default
behavior, or a task. Except shell commands which are executed with [shelljs](https://github.com/arturadib/shelljs),
all commands are currently run with ```sh -c```

### Notes:

Everything in the ```build.yml``` is holy, so plugins will never alter your
settings. They can and will, however, complete with all the missing fields.

It also means that if a rule already exists in your ```build.yml``` file, then
it will be left untouched and executed as it is defined. As an example:

```yaml
init:
  plugins:
    - clean
clean:
  - echo FUBAR!
```

This will avoid plugins' ```clean``` target to be merged and you will only see
a holy _FUBAR!_ message.

## Plugins

Some tasks are repetitive and could be nicely reused. As a typical example,
our ```clean``` rule is most likely handled by a simple ```rm -rf {list-of-paths}```.

So this is where ```plugins``` come into play !

Basically a plugin can be either a ```.coffee``` file, a ```.js``` file or a ```.yaml``` file.

Each plugin must define at least one of the two between ```settings``` and ```rules```.

### YAML example

```yaml
# Adds these new settings and rules

settings:
  toClean: ['lib']
  toDistclean: ['node_modules']
clean:
  - exec: rm -rf %toClean
distclean:
  - task: clean
  - exec: rm -rf %toDistclean
```

And this is a quick'n'nice handling of simple ```clean``` and ```distclean``` tasks.
See also the default settings for each one and the order they will be run.

### CoffeeScript example

```coffee
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
```

When using ```Coffeescript``` or ```Javascript``` you will have more leverage on
what you can do. Plugins are run within a [sandbox-runner](https://github.com/timnew/sandbox-runner).

After parsing, ```settings``` and ```rules``` will be evaluated  as a function
or as a Plain Old Object.

> ```rules``` will be evaluated right after merging settings so if your plugin
relies on some configuration option another plugin defines, then make sure you
ordered plugin loading correctly !

The plugin architecture accepts both ```String``` and ```Object``` in return for
both ```settings``` and ```rules```.

If an ```Object``` is returned it will be merged as-is.

If a ```String``` is returned it will be parsed as YAML before merge.

### Require example

```coffee
fs = require 'fs'
packagejson = JSON.parse fs.readFileSync 'package.json'

@settings =
  name: packagejson.name
  version: packagejson.version
  licenses: packagejson.licenses
```

This example shows how you can access pretty much anything if you want to
customize your own build with external tools and libraries.

## Bugs

Don't see any at the moment :smile: !

Feel free to open a new issue if you find any. Suggestions and PR are always welcome !

## TODO

* Add --watch option
* Add --report option
* More and more tests...
