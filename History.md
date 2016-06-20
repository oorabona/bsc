0.7.0
=====
* Moved plugins from main code to `ubs-plugins` package
* Added variable substition pre-process with enclosing and separator facilities
* Fixed grab test

0.6.8
=====
* Fixed `shellArgs` so that it accepts `strings` and `arrays`
* Updated `grab` plugin calling method to accept string and array based parameters.
* `parseCommand` now accept commands in string or array fashion

0.6.7
=====
* Added multi environment support
* New syntax for exec-ing conditionally

0.6.6
=====
* Fixed back propagation of changes in environment variables from children to parent
* Added ```%ubs%``` variable that points to ourselves (argv[0])
* Fixed bug of ```coffee-script``` not being available at runtime
* Added new tests for internal shell commands
* Added `osx` to the list of supported platforms! :smile:

0.6.2
=====
* Config can now be addressed directly, no more indirection when requiring.
* Update all deps to their latest version
* Fixed ```--no-colors``` option
* Code cleanup

0.6.1
=====
* Fixed ```grab``` plugin not resolving promise!
* Minor cosmetic changes (comments, etc).

0.6.0
=====
* Shows help when called without arguments instead of throwing error about file not found
* Refactored plugin parseCommand to be easier to use
* __New__: ```UBS_BUILD``` is no longer used, instead a ```UBS_OPTS``` will be prepended to the command line and therefore precedes commandline parameters in evaluation.
* Removed unneeded dependencies
* Fixed command line variable setting: ```ubs variables.can.now[0].be.like.that=true``` now works
* Other minor fixes here and there

0.5.0
=====
* New way for templating (string search/replace) in ```command```: %variable% (yeah the trailing '%')
* ```clean``` plugin now has its own attribute root in settings
* Plugins can now use ```Utils``` to take ```actions```
* ```%variables.can.now[0].be.like.that%```
* Plugins settings can now be initialized with the current settings context as argument. That allows dependency checking across plugins.
* Added customization of shell commands and arguments to run scripts (portability!)

0.4.x
=====
* Fixed command line settings override
* Fixed various bugs

0.3.x
=====
* Added variables and text search/replace
* Added actions like (e.g in a step) ```- callme: '%maybe'```
* Added new plugin: ```grab```
