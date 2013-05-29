fs = require 'fs'
cp = require 'child_process'


task 'compile', 'compile CoffeeScript', ->
  coffee = cp.spawn 'coffee', [
    '-cmw',
    'lib'
  ],
    stdio: 'inherit'

task 'doc', 'generate coffee doc', ->


task 'test', 'run tests', ->
  cp.spawn 'mocha', [
    '--compilers', 'coffee:coffee-script',
    'test'
  ], {
    stdio: 'inherit'
  }


