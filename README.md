# Unified Build System

> 'Write as little code as you can'
-- Yoda

This package is another Javascript builder like [Grunt](http://gruntjs.com), [Cake](http://www.coffeescript.org) or [Gulp](http://gulpjs.com) but with YAML like [Travis CI](http://travis-ci.org) ```.travis.yml``` containing (enhanced) single line ```Makefile```-like instructions.

Hence the _Unified_.

## What's new in 0.4.0 ?

Sometimes you need to conditionally call a part of your script. Many solutions
exist but by spawning ourselves, conditions are shell scripted. This allows quick
and easy environment variables checks and clear separation between actions and
conditions.

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
  - '[ "$TEST" = "bad" ] && $_ -b path/to/build.yml test2'
  # The spawned process can also back propagate environment variables
  - echo Expecting test to be $TEST
test2:
  - env: TEST="working!"
```

First line is plain shell scripting and syntax may vary. If and only if ```TEST``` is equal to ```bad``` shall we change to ```working```. And we do that by spawning ourselves. Most shells set ```$_``` to the executable name you entered in the shell, but if not the case you may just replace by _ubs_.

## How it works

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
> At the moment _watch_ is not supported, see [TODO](#TODO)

## The build.yml

The build file is all [YAML](http://yaml.org) and follows a pattern close to
Makefile.

```yaml
# The init part is run first. It looks for plugins to load (in order, but order
# in this example does not really matter).
init:
  plugins:
    - mocha
    - packagejson
    - clean
# It is the place to set plugins variables. Plugins can add extra key=value
# settings, as for Mocha where 'bin' and 'useCoffee'. Mocha options are modified
# accordingly. The special 'env' can be overridden to add new environment variables.
# We tell 'clean' package to not remove 'lib' globally but only the core build.
# This allows plugins to remain intact for next build.
settings:
  cleanPath: ['lib/*.js']
  srcPath: 'src'
  libPath: 'lib'
  mocha:
    bin: 'mocha'
    useCoffee: true
prebuild:
  - npm update
# You can call shell commands as well. In the build task, %name and %version are
# variables from settings above. They are replaced in place before running command.
build:
  - echo Building %name version %version ...
  - coffee -o %libPath -c %srcPath/*.coffee
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
  - mkdir -p %libPath/plugins
  - cp -f %srcPath/plugins/* %libPath/plugins/
  - echo Installation complete, you can 'cd %libPath'
```

Each sequence can either be a command to execute, this is the default, or
a task. Except shell commands which are executed with [shelljs](https://github.com/arturadib/shelljs),
all commands are currently run with ```sh -c```

You can also use one of the following builtin actions:

```yaml
- log: notice level %version
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
  - echo Retrieving %fileUrl
  - grab: "%fileUrl"
```

> Note: For the above example, and the above example only, you need to include __grab__ plugin.

### Notes:

Everything in the ```build.yml``` is holy, so plugins will never alter your
settings. They can and will, however, complete with all the missing fields.

It also means that if a rule already exists in your ```build.yml``` file, it will be left untouched and executed as it is defined.

```yaml
init:
  plugins:
    - clean
clean:
  - echo FUBAR!
```

In the above example, overriding 'clean' target will short circuit plugins' ```clean``` target, and therefore you will only see
the holy _FUBAR!_ message. :smile:

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
You can also set default values for each one and the order each task will be run.

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
relies on some configuration option another plugin defines, you have to make sure you
ordered plugins loading correctly !

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

As you can see, you can do pretty much anything you want to
customize your own build with external tools and libraries.

### Using actions

Introduced with 0.3.0, you can now define ```actions```.
Actions are set like ```settings``` or ```rules``` but have slight differences.

An example to start with:
```coffee
@actions = (logging, config) ->
  grab: (command, settings) ->
    # Do stuff (see src/plugins/ubs-grab.coffee)
```

So basically when plugin is loaded, if ```actions``` exists, it must be a function. This function will be called by the plugin manager with two parameters:
- logging: internal __logging__ instance
- config: internal __config__ instance

With these two you can co-operate with __UBS__ internals without much hassle.

You may have more than one ```action``` defined by a plugin but you cannot redefine
an existing action.

> ```actions``` function must return an object. That object will extend existing [Dispatch](https://github.com/oorabona/ubs/tree/master/src/dispatch.coffee) object.

> Actions will be run within the __Dispatch__ context and must comply with the existing [Q Promises](https://github.com/kriskowal/q). So each defined action must return a promise and that promise must be either ```resolved``` or ```rejected```.

## Bugs

Don't see any at the moment :wink: !

Feel free to open a new issue if you find any. Suggestions and PR are always welcome !

## TODO

* Add --watch option
* Add --report option
* More and more tests...
