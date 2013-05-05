cp = require 'child_process'

task 'test', 'run tests', ->
  cp.spawn 'mocha', [
    '--compilers', 'coffee:coffee-script', 'test'
  ], {
    stdio: 'inherit'
  }


