path = require 'path'
fs = require 'fs'
{ spawn } = require 'child_process'
chai = require 'chai'
chai.should()


valid =
  coffee: fs.readFileSync(path.join(__dirname, 'lib-valid/.coffee'), 'utf8')
  js: fs.readFileSync(path.join(__dirname, 'lib-valid/.js'), 'utf8')


rmdirSync = (dir) ->
  for file in fs.readdirSync dir
    file = path.join dir, file
    if fs.statSync(file).isDirectory()
      rmdirSync file
    else
      fs.unlinkSync file
  fs.rmdirSync dir


describe 'coffeemill', ->
  describe '-i src -o lib', ->
    coffeemill = spawn path.join(__dirname, '../bin/coffeemill'), [
      '-i', 'src'
      '-o', 'lib'
      '-cj'
    ],
      cwd: __dirname

    coffeemill.stdout.setEncoding 'utf8'
    coffeemill.stdout.on 'data', (data)->
      console.log data

    err = ''
    coffeemill.stderr.setEncoding 'utf8'
    coffeemill.stderr.on 'data', (data)->
      err += data

    it 'should be output valid code', (done) ->
      coffeemill.once 'close', ->
        throw err if err isnt ''

        fs.readFileSync(path.join(__dirname, 'lib/.coffee'), 'utf8').should.be.equal valid.coffee
        fs.readFileSync(path.join(__dirname, 'lib/.js'), 'utf8').should.be.equal valid.js
        rmdirSync path.join(__dirname, 'lib')

        done()
