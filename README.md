# Unified Build System

[![NPM Version](https://img.shields.io/npm/v/ubs.svg)](https://npmjs.org/package/ubs)
[![NPM Downloads](https://img.shields.io/npm/dm/ubs.svg)](https://npmjs.org/package/ubs)
[![Build Status](https://travis-ci.org/oorabona/ubs.png)](https://travis-ci.org/oorabona/ubs)
[![Dependency Status](https://david-dm.org/oorabona/ubs.svg)](https://david-dm.org/oorabona/ubs)
[![devDependency Status](https://david-dm.org/oorabona/ubs/dev-status.svg)](https://david-dm.org/oorabona/ubs#info=devDependencies)

> 'Write as little code as you can'

This package is another Javascript builder like [Grunt](http://gruntjs.com), [Cake](http://www.coffeescript.org) or [Gulp](http://gulpjs.com) but with YAML like [Travis CI](http://travis-ci.org) ```.travis.yml``` containing (enhanced) single line ```Makefile```-like instructions.

Also, it was intended to be as simple as possible to call from ```npm run``` so that you can map ```npm``` script names to ```ubs``` counterparts. Hence the _Unified_.

## How it works

There are three kind of items you can find:
- init: set up plugin, global config etc.
- settings: contains variables (which can be overridden) used by plugins, or not, at runtime.
- tasks: a target like ```install```, ```test``` and all others...

You need a ```build.yml``` in your __current working directory__ and that's it.

```shell
$ ubs
```

By default, __ubs__ will look for a target named 'install'.
But you can select your targets:

```shell
$ ubs clean test
```

Targets will be run in sequence and depending tasks will be automatically added.

```shell
$ ubs --help
ubs 0.4.0
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
> At the moment _watch_ is not implemented, see [TODO](#TODO)

## The build.yml

The build file is all [YAML](http://yaml.org) and follows a pattern close to Makefile.

It first may contain an ```init``` part, defining global context.
E.g. this is where you load [plugins](#plugins).

```yaml
# The init part is run first. It looks for plugins to load (in order, but order
# in this example does not really matter).
init:
  plugins:
    - mocha
    - packagejson
    - clean
    - grab
```

In this example, we load all four default plugins so far.

Then, the ```settings``` section where all you can set/override default values coming from default values used in plugins.
In the following example, ```mocha``` plugin stores/retrieves its own settings from under ```mocha``` and ```clean``` plugin has also its own attribute object.

```yaml
# It is the place to set plugins variables. Plugins can add extra key=value
# settings, as for Mocha where 'bin' and 'useCoffee'. Mocha options are modified
# accordingly. The special 'env' can be overridden to add new environment variables.
# We tell 'clean' package to not remove 'lib' globally but only the core build.
# This allows plugins to remain intact for next build.
settings:
  clean:
    path: ['lib/*.js']
    distclean: ['node_modules']
  srcPath: 'src'
  libPath: 'lib'
  mocha:
    useCoffee: true
```

A special kind of setting __exec__ is used to change behavior of all exec commands.

```yaml
settings:
  exec:
    shellCmd: '/bin/sh'
    shellArgs: '-c'
    env:
      CPPFLAGS: "-fPIC"
      CFLAGS: "-O3"
```

And all the rest are targets. By default ```ubs``` looks for ```install```.

```yaml
prebuild:
  - npm update
# You can call shell commands as well. In the build task, %name and %version are
# variables from settings above. They are replaced in place before running command.
build:
  - echo Building %name version %version ...
  - coffee -o %libPath% -c %srcPath%/*.coffee
# Sometimes you rely on other tasks, so that is the way you call them.
# Here mocha-test is a rule created by the 'mocha' plugin
test:
  - task: install
  - task: mocha-test
# Splitted install and install_plugins because building UBS requires these plugins
# to be installed first hand. This build.yml needs them in their expected places.
install:
  - task: install_plugins
  - task: build
install_plugins:
  - echo Moving plugins to lib/plugins folder
  - mkdir -p %libPath%/plugins
  - cp -f %srcPath%/plugins/* %libPath%/plugins/
  - echo Installation complete, you can 'cd %libPath%'
```

Each sequence can either be a command to ```exec```ute, this is the default, or an action, like calling a new ```task```.
Except some shell commands which are executed with [shelljs](https://github.com/arturadib/shelljs), all commands are currently run with the specified shell and its attributes.

__ShellJS__ handles the following common shell commands:

- ```cat```
- ```cd```
- ```chmod```
- ```cp```
- ```dirs```
- ```exit```
- ```grep```
- ```ls```
- ```mkdir```
- ```mv```
- ```popd```
- ```pushd```
- ```pwd```
- ```rm```
- ```sed```
- ```test```

> By default, on Windows __shellCmd__ is ```cmd.exe``` and __shellArgs__ ```-c```.
> Otherwise, it's ```/bin/sh``` and ```-c``` respectively.

Along with ```task```, you can also use one of the following builtin actions:

```yaml
- log: notice level %version%
- log:
  debug: debug level
```

```yaml
- echo $WTF
- env: WTF=still works!
- echo $WTF
```

And if you want to retrieve a file from elsewhere (using [request](https://github.com/request/request)).

```yaml
init:
  plugins:
    - "grab"
settings:
  fileUrl: https://github.com/oorabona/ubs/archive/master.zip
  grabTmpDir: test
test:
  - echo Retrieving %fileUrl%
  - grab: "%fileUrl%"
```

Which will download the file and store it in ```grabTmpDir``` .

## Calling different build sequences

Sometimes you might want to conditionally run a part of a build. To do so you can spawn ```ubs``` again.

That would be a typical use case:

```yaml
settings:
  exec:
    env:
      TEST: "bad"
test:
  - echo Test is $TEST
  # If you want to conditionally call another build you may have
  # to enclose within quotes..
  - '[ "$TEST" = "bad" ] && %bin% -b path/to/build.yml test2'
  # The spawned process can also back propagate environment variables
  - echo Expecting test to be $TEST
test2:
  - env: TEST="working!"
```

First line is plain shell scripting (will be prefixed by ```sh -c```). If and only if ```$TEST``` is equal to ```bad``` shall we change to ```working```. And we do that by spawning ourselves. Most shells set ```$_``` to refer the executable name you entered in the shell, but if not the case you may use a setting (here ```bin```) to make sure the correct command is run.

### Notes

Everything in the ```build.yml``` is holy, so plugins will never alter your settings. On the contrary, they are meant to provide default _workable_ functionality but if needed, everything can be overridden.

This also means that if a rule exists in your ```build.yml``` file that also exists in a plugin, your version will take over the default from plugin.

```yaml
init:
  plugins:
    - clean
clean:
  - echo FUBAR!
```

In the above example, overriding 'clean' target will short circuit plugins' ```clean``` target, and therefore you will see the holy _FUBAR!_ message _instead_ of having your project a bit cleaned up.

## Plugins

As our ```clean``` rule above, some tasks are repetitive and could be nicely reused. So this is where ```plugins``` come into play !

Basically a plugin can be either a ```.coffee``` file, a ```.js``` file or a ```.yaml``` file.

Each plugin can define these parameters:

Type | Use | Return type | If a function, signature
-----|-----|-------------|-------------------------
settings | All your settings belong to here | ```String``` or ```Object``` | ```settings(currentSettings) {}```
rules | All tasks/targets to be added to the build file | ```String``` or ```Object``` | ```rules(settings) {}```
actions | Add functionality with new prefixes for tasks definitions (steps) | ```Promise``` | ```actions(logging, config, helpers) {}```

The plugin architecture accepts both ```String``` and ```Object``` in return for
both ```settings``` and ```rules```.

If an ```Object``` is returned it will be merged as-is.

If a ```String``` is returned it will be parsed as YAML before merge.

> A single plugin can combine any of the three parameters.
> These parameters can be defined either _statically_ or you can scope them as functions.
> __Actions can only be defined as functions !!__ (see below)

### YAML example

For instance, take this cleaning example. This is what is actually written in the code to achieve this task.

```yaml
# Adds these new settings and rules

settings:
  clean:
    path: ['lib']
    distclean: ['node_modules']
clean:
  - exec: rm -rf %clean.path%
distclean:
  - task: clean
  - exec: rm -rf %clean.distclean%
```

Nice, isn't it ?

> Plugins __should__ create their own _attribute_ object so that we keep everything clean.
> Top level attributes can then be freely used at your convenience.

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

After parsing, ```settings``` and ```rules``` will be evaluated either as a function or as a Plain Old Object.

> __NOTE:__ ```rules``` will be evaluated right after merging settings so if your plugin
relies on some configuration option another plugin defines, you have to make sure you
ordered plugins loading correctly ! (see ```init```)

### Require example

```coffee
fs = require 'fs'
packagejson = JSON.parse fs.readFileSync 'package.json'

@settings =
  name: packagejson.name
  version: packagejson.version
  licenses: packagejson.licenses
```

As you can see, you can do pretty much anything you want to customize your own build with external tools and libraries.

### Using actions

Actions are set like ```settings``` or ```rules``` but have slight differences.

An example to start with:

```coffee
@actions = (logging, config) ->
  grab: (command, settings) ->
    # Do stuff (see src/plugins/ubs-grab.coffee)
```

When plugin is loaded, if ```actions``` exists, it must be a function. This function will be called by the plugin manager with two parameters:
- logging: internal __logging__ instance
- config: internal __config__ instance
- helpers: internal __utils__ instance

With these two you can co-operate with __UBS__ internals without hassle.

You may have more than one ```action``` defined by a plugin but you cannot redefine an existing action (like ```exec``` for example).

> ```actions``` function must return an object. That object will extend existing [Dispatch](https://github.com/oorabona/ubs/tree/master/src/dispatch.coffee) object.

> Actions will be run within the __Dispatch__ context and therefore must comply with the existing [Q Promises](https://github.com/kriskowal/q). So each defined action must return a promise and that promise must be either ```resolved``` or ```rejected```.

## Bugs

Don't see any at the moment :wink: !

Feel free to open a new issue if you find any. Suggestions and PR are always welcome !

## TODO

* Add --watch option
* Add --report option
* More and more tests...
