name = {
  "space": {}
}
if window? then window.name = name
if module? then module.exports = name

class name.space.Baz

  constructor: (classNames = []) ->
    classNames.unshift 'Baz'
    console.log classNames.join '->'

class Foo extends name.space.Baz

  constructor: (classNames = []) ->
    classNames.push 'Foo'
    super classNames

class name.Bar extends Foo

  constructor: (classNames = []) ->
    classNames.unshift 'Bar'
    super classNames