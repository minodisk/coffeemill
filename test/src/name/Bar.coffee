class Bar extends Foo

  constructor: (classNames = []) ->
    classNames.unshift 'Bar'
    super classNames