chai = require 'chai'
expect = chai.expect
chai.should()

{spawn} = require 'child_process'
fs = require 'fs'

describe 'coffeemill', ->
  coffeemill = spawn '../bin/coffeemill'

  it 'stderr', (done) ->
    coffeemill.stderr.setEncoding 'utf8'
    coffeemill.stderr.on 'data', (data)->
      data.should.not.exist()
      done()

  it 'close', (done) ->
    coffeemill.once 'close', ->
      fs.existsSync('lib/.js').should.be.true
      done()
