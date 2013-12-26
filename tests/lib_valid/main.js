(function() {
  var Parent, name, ___exports,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  name = {
    "space": {}
  };

  ___exports = {
    "name": {
      "space": {}
    }
  };

  ___exports.Parent = Parent = (function() {
    function Parent() {
      this.names = [];
      this.addName('Parent');
    }

    Parent.prototype.addName = function(name) {
      return this.names.push(name);
    };

    Parent.prototype.inheritance = function() {
      return this.names.join('->');
    };

    return Parent;

  })();

  ___exports.name.Child = name.Child = (function(_super) {
    __extends(Child, _super);

    function Child() {
      Child.__super__.constructor.call(this);
      this.addName('Child');
    }

    return Child;

  })(Parent);

  ___exports.name.space.GrundChild = name.space.GrundChild = (function(_super) {
    __extends(GrundChild, _super);

    function GrundChild() {
      GrundChild.__super__.constructor.call(this);
      this.addName('GrundChild');
    }

    return GrundChild;

  })(name.Child);

  (function() {
    var ___extend;
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
      ___extend(window, ___exports);
    }
    if ((typeof module !== "undefined" && module !== null ? module.exports : void 0) != null) {
      return ___extend(module.exports, ___exports);
    }
  })();

}).call(this);
