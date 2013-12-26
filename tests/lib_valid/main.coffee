name = {"space":{}}

___exports = {"name":{"space":{}}}

___exports.Parent = class Parent

  constructor: ->
    @names = []
    @addName 'Parent'

  addName: (name) ->
    @names.push name

  inheritance: ->
    @names.join '->'

___exports.name.Child = class name.Child extends Parent

  constructor: ->
    super()
    @addName 'Child'

___exports.name.space.GrundChild = class name.space.GrundChild extends name.Child

  constructor: ->
    super()
    @addName 'GrundChild'

do ->
  ___extend = (child, parent) ->
    for key, val of parent
      continue unless Object::hasOwnProperty.call parent, key
      if Object::toString.call(val) is '[object Object]'
        child[key] = {}
        ___extend child[key], val
      else
        child[key] = val
  if window?
    ___extend window, ___exports
  if module?.exports?
    ___extend module.exports, ___exports