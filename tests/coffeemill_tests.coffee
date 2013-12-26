path = require 'path'
fs = require 'fs'
{ spawn } = require 'child_process'
chai = require 'chai'
chai.should()


valid =
  coffee: fs.readFileSync(path.join(__dirname, 'lib_valid/main.coffee'), 'utf8')
  js: fs.readFileSync(path.join(__dirname, 'lib_valid/main.js'), 'utf8')


rmdirSync = (dir) ->
  for file in fs.readdirSync dir
    file = path.join dir, file
    if fs.statSync(file).isDirectory()
      rmdirSync file
    else
      fs.unlinkSync file
  fs.rmdirSync dir


describe 'coffeemill', ->
  describe '-i src -o lib -cj', ->
    coffeemill = spawn path.join(__dirname, '../bin/coffeemill'), [
      '-i', 'src'
      '-o', 'lib'
      '-cj'
    ],
      cwd: __dirname

    coffeemill.stdout.setEncoding 'utf8'
    coffeemill.stdout.on 'data', (data)-> console.log data

    err = ''
    coffeemill.stderr.setEncoding 'utf8'
    coffeemill.stderr.on 'data', (data)->
      err += data

    it 'should exports all level classes', (done) ->
      coffeemill.once 'close', ->
        { Parent, name: { Child, space: { GrundChild }}} = require './lib/main'
        new Parent().inheritance().should.be.equal 'Parent'
        new Child().inheritance().should.be.equal 'Parent->Child'
        new GrundChild().inheritance().should.be.equal 'Parent->Child->GrundChild'
        done()


#      coffeemill.once 'close', ->
#        throw err if err isnt ''
#
#        fs.readFileSync(path.join(__dirname, 'lib/main.coffee'), 'utf8').should.be.equal valid.coffee
#        fs.readFileSync(path.join(__dirname, 'lib/main.js'), 'utf8').should.be.equal valid.js
#        rmdirSync path.join(__dirname, 'lib')
#
#        done()
