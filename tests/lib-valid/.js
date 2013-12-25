(function() {
  var Foo, name,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  name = {
    "space": {}
  };

  if (typeof window !== "undefined" && window !== null) {
    window.name = name;
  }

  if (typeof module !== "undefined" && module !== null) {
    module.exports = name;
  }

  name.space.Baz = (function() {
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

  name.Bar = (function(_super) {
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

}).call(this);
