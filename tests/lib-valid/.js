(function() {
  var Foo, name, ___extend, _base,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  ___extend = function(child, parent) {
    var key, val, _results;
    _results = [];
    for (key in parent) {
      val = parent[key];
      if (!Object.prototype.hasOwnProperty.call(parent, key)) {
        continue;
      }
      if (Object.prototype.toString.call(val) === '[object Object]') {
        child[key] = {};
        _results.push(___extend(child[key], val));
      } else {
        _results.push(child[key] = val);
      }
    }
    return _results;
  };

  if (typeof window !== "undefined" && window !== null) {
    if (window.name == null) {
      window.name = {};
    }
    name = window.name;
  }

  if ((typeof module !== "undefined" && module !== null ? module.exports : void 0) != null) {
    if ((_base = module.exports).name == null) {
      _base.name = {};
    }
    name = module.exports.name;
  }

  ___extend(name, {
    "space": {}
  });

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
