path = require 'path'
fs = require 'fs'
{ spawn } = require 'child_process'

chai = require 'chai'
{ expect } = chai
chai.should()


describe 'no option', ->
  coffeemill = spawn path.join(__dirname, '..', 'bin/coffeemill'), null,
    cwd: __dirname

  out = ''
  coffeemill.stdout.setEncoding 'utf8'
  coffeemill.stdout.on 'data', (data)->
    console.log out
    out += data

  err = ''
  coffeemill.stderr.setEncoding 'utf8'
  coffeemill.stderr.on 'data', (data)->
    err += data

  it 'close', (done) ->
    coffeemill.once 'close', ->
      throw err if err isnt ''
      true.should.be.true
      done()
