___extend = (child, parent) ->
  for key, val of parent
    continue unless Object::hasOwnProperty.call parent, key
    if Object::toString.call(val) is '[object Object]'
      child[key] = {}
      ___extend child[key], val
    else
      child[key] = val

if window?
  window.name ?= {}
  name = window.name
if module?.exports?
  module.exports.name ?= {}
  name = module.exports.name
___extend name, {"space":{}}

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