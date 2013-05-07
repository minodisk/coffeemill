fs = require 'fs'
cp = require 'child_process'

task 'watch', 'watch file', ->
  invoke 'compile'


task 'compile', 'compile CoffeeScript', ->
  coffee = cp.spawn 'coffee', [
    '-cm',
    'lib'
  ]

  err = ''
  coffee.stderr.setEncoding 'utf8'
  coffee.stderr.on 'data', (data) ->
    err += data

  out = ''
  coffee.stdout.setEncoding 'utf8'
  coffee.stdout.on 'data', (data) ->
    out += data

  coffee.on 'close', ->
    throw err unless err is ''
    console.log out
    invoke 'test'

task 'test', 'run tests', ->
  cp.spawn 'mocha', [
    '--compilers', 'coffee:coffee-script',
    'test'
  ], {
    stdio: 'inherit'
  }


