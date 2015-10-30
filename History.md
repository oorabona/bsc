0.5.0
=====
* New way for templating (string search/replace) in ```command```: %variable% (yeah the trailing '%')
* ```clean``` plugin now has its own attribute root in settings
* Plugins can now use ```Utils``` to take ```actions```
* %variables.can.now[0].be.like.that%
* Plugins settings can now be initialized with the current settings context as argument. That allows dependency checking across plugins.
* Added customization of shell commands and arguments to run scripts (portability!)

0.4.x
=====
* Fixed command line settings override
* Fixed various bugs

0.3.x
=====
* Added variables and text search/replace
* Added actions like (e.g in a step) ```- callme: '%maybe%'```
* Added new plugin: ```grab```
