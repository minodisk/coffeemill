fs = require 'fs'
cp = require 'child_process'


task 'compile', 'compile CoffeeScript', ->
  coffee = cp.spawn 'coffee', [
    '-cmw',
    'lib'
  ],
    stdio: 'inherit'


task 'test', 'run tests', ->
  cp.spawn 'npm', ['test'],
    stdio: 'inherit'


