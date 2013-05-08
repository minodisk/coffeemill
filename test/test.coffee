path = require 'path'
fs = require 'fs'
{ spawn } = require 'child_process'

chai = require 'chai'
{ expect } = chai
chai.should()


COFFEE = """class Baz

  constructor: (classNames = []) ->
    classNames.unshift 'Baz'
    console.log classNames.join '->'

class Foo extends name.space.Baz

  constructor: (classNames = []) ->
    classNames.push 'Foo'
    super classNames

class Bar extends Foo

  constructor: (classNames = []) ->
    classNames.unshift 'Bar'
    super classNames

window[k] = v for k, v of {
  "name": {
    "space": {
      "Baz": Baz
    },
    "Bar": Bar
  },
  "Foo": Foo
}"""

JS = """(function() {
  var Bar, Baz, Foo, k, v, _ref,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  Baz = (function() {
    function Baz(classNames) {
      if (classNames == null) {
        classNames = [];
      }
      classNames.unshift('Baz');
      console.log(classNames.join('->'));
    }

    return Baz;

  })();

  Foo = (function(_super) {
    __extends(Foo, _super);

    function Foo(classNames) {
      if (classNames == null) {
        classNames = [];
      }
      classNames.push('Foo');
      Foo.__super__.constructor.call(this, classNames);
    }

    return Foo;

  })(name.space.Baz);

  Bar = (function(_super) {
    __extends(Bar, _super);

    function Bar(classNames) {
      if (classNames == null) {
        classNames = [];
      }
      classNames.unshift('Bar');
      Bar.__super__.constructor.call(this, classNames);
    }

    return Bar;

  })(Foo);

  _ref = {
    "name": {
      "space": {
        "Baz": Baz
      },
      "Bar": Bar
    },
    "Foo": Foo
  };
  for (k in _ref) {
    v = _ref[k];
    window[k] = v;
  }

}).call(this);
"""


rmdirSync = (dir) ->
  for file in fs.readdirSync dir
    file = path.join dir, file
    if fs.statSync(file).isDirectory()
      rmdirSync file
    else
      fs.unlinkSync file
  fs.rmdirSync dir


#describe 'no option', ->
#  coffeemill = spawn path.join(__dirname, '..', 'bin/coffeemill'), null,
#    cwd: __dirname
#
#  out = ''
#  coffeemill.stdout.setEncoding 'utf8'
#  coffeemill.stdout.on 'data', (data)->
#    out += data
#
#  err = ''
#  coffeemill.stderr.setEncoding 'utf8'
#  coffeemill.stderr.on 'data', (data)->
#    err += data
#
#  it 'close', (done) ->
#    coffeemill.once 'close', ->
#      throw err if err isnt ''
#
#      console.log out
#      fs.readFileSync(path.join(__dirname, 'lib/.coffee')).should.be.COFFEE
#      fs.readFileSync(path.join(__dirname, 'lib/.js')).should.be.JS
#      rmdirSync path.join(__dirname, 'lib')
#
#      done()


describe 'input/output', ->
  coffeemill = spawn path.join(__dirname, '..', 'bin/coffeemill'), [
      '-i', 'src'
      '-o', 'lib'
    ],
    cwd: __dirname

  coffeemill.stdout.setEncoding 'utf8'
  coffeemill.stdout.on 'data', (data)->
    console.log data

  err = ''
  coffeemill.stderr.setEncoding 'utf8'
  coffeemill.stderr.on 'data', (data)->
    err += data

  it 'close', (done) ->
    coffeemill.once 'close', ->
      throw err if err isnt ''

      fs.readFileSync(path.join(__dirname, 'lib/.coffee')).should.be.COFFEE
      fs.readFileSync(path.join(__dirname, 'lib/.js')).should.be.JS
      rmdirSync path.join(__dirname, 'lib')

      done()
