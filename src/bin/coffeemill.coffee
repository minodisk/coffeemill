#!/usr/bin/env node

path = require 'path'
fs   = require 'fs'
lib  = path.join fs.realpathSync(__dirname), '../lib'

require(path.join(lib + '/coffeemill')).run()