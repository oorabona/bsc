###
Package.json module for UBS

Provides settings with package.json information.
At the moment only 'name', 'version' and 'licenses' are handled
###

fs = require 'fs'
packagejson = JSON.parse fs.readFileSync 'package.json'

@settings =
  name: packagejson.name
  version: packagejson.version
  license: packagejson.license or packagejson.licenses
