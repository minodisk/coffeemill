class Parent

  constructor: ->
    @names = []
    @addName 'Parent'

  addName: (name) ->
    @names.push name

  inheritance: ->
    @names.join '->'