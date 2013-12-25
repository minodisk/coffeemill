class name.space.Baz

  constructor: (classNames = []) ->
    classNames.unshift 'Baz'
    console.log classNames.join '->'