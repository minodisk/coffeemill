(function() {
  var CoffeeMill, Relay, coffee, fs, parser, path, spawn, uglify, _ref,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

  fs = require('fs');

  path = require('path');

  spawn = require('child_process').spawn;

  coffee = require('coffee-script');

  _ref = require('uglify-js'), parser = _ref.parser, uglify = _ref.uglify;

  Relay = require('relay').Relay;

  exports.CoffeeMill = CoffeeMill = (function() {

    CoffeeMill.R_ENV = /#if\s+BROWSER([\s\S]*?)(#else[\s\S]*?)?#endif/g;

    CoffeeMill.version = function() {
      var package;
      package = JSON.parse(fs.readFileSync(path.join(__dirname, '../package.json'), 'utf8'));
      return package.version;
    };

    CoffeeMill.help = function() {
      return "Usage    : coffeemill [-o output_dir] [-t test_dir] [src_dir]\nOptions  : -v, --version print coffeemill's version\n           -h, --help    print coffeemill's help\n           -o, --output  output directory (DEFAULT lib)\n           -t, --test    test directory (DEFAULT test)\nArgument : watching directory (DEFAULT src)";
    };

    function CoffeeMill() {
      this.test = __bind(this.test, this);
      this.startCompile = __bind(this.startCompile, this);
      this.onDirChanged = __bind(this.onDirChanged, this);
      this.startWatch = __bind(this.startWatch, this);      this.requested = false;
    }

    CoffeeMill.prototype.grind = function(srcDir, dstDir, testDir, isComplress) {
      this.srcDir = srcDir != null ? srcDir : 'src';
      this.dstDir = dstDir != null ? dstDir : 'lib';
      this.testDir = testDir != null ? testDir : 'test';
      this.isComplress = isComplress != null ? isComplress : false;
      this.startWatch();
      return this.startCompile();
    };

    CoffeeMill.prototype.startWatch = function() {
      var self;
      self = this;
      return Relay.each(Relay.serial(Relay.func(function(dir) {
        this.local.dir = dir;
        return fs.stat(dir, this.next);
      }), Relay.func(function(err, stats) {
        if (err == null) {
          console.log("" + (self.timeStamp()) + " Start watching directory: " + this.local.dir);
          fs.watch(this.local.dir, self.onDirChanged);
        }
        return this.next();
      }))).start([self.srcDir, self.testDir]);
    };

    CoffeeMill.prototype.onDirChanged = function(event, filename) {
      var self;
      self = this;
      if (!self.requested) {
        console.log("" + (self.timeStamp()) + " Detect changed");
        self.requested = true;
        return setTimeout((function() {
          self.requested = false;
          return self.startCompile();
        }), 1000);
      }
    };

    CoffeeMill.prototype.timeStamp = function() {
      var date;
      date = new Date();
      return "" + (this.padLeft(date.getHours())) + ":" + (this.padLeft(date.getMinutes())) + ":" + (this.padLeft(date.getSeconds()));
    };

    CoffeeMill.prototype.padLeft = function(num, length, pad) {
      var str;
      if (length == null) length = 2;
      if (pad == null) pad = '0';
      str = num.toString(10);
      while (str.length < length) {
        str = pad + str;
      }
      return str;
    };

    CoffeeMill.prototype.startCompile = function() {
      var self;
      self = this;
      return Relay.serial(Relay.func(function() {
        console.log("" + (self.timeStamp()) + " Start compiling.");
        return this.next();
      }), Relay.func(function() {
        return fs.readdir(self.srcDir, this.next);
      }), Relay.func(function(err, files) {
        if (err != null) {
          return console.log(err);
        } else {
          return this.next(files);
        }
      }), Relay.each(Relay.serial(Relay.func(function(file) {
        this.local.basename = path.basename(file, path.extname(file));
        return fs.readFile(path.join(self.srcDir, file), 'utf8', this.next);
      }), Relay.func(function(err, code) {
        var browser, files, node;
        if (err != null) {
          return this.skip();
        } else {
          if (CoffeeMill.R_ENV.test(code)) {
            node = coffee.compile(code.replace(CoffeeMill.R_ENV, function(matched, $1, $2, offset, source) {
              if ($2 != null) {
                return $2;
              } else {
                return '';
              }
            }));
            browser = coffee.compile(code.replace(CoffeeMill.R_ENV, function(matched, $1, $2, offset, source) {
              if ($1 != null) {
                return $1;
              } else {
                return '';
              }
            }));
            files = [
              {
                path: "node/" + this.local.basename + ".js",
                code: node
              }, {
                path: "browser/" + this.local.basename + ".js",
                code: browser
              }
            ];
            if (self.isComplress) {
              files.push({
                path: "browser/" + this.local.basename + ".min.js",
                code: self.compress(browser)
              });
            }
            return this.next(files);
          } else {
            code = coffee.compile(code);
            files = [
              {
                path: "" + this.local.basename + ".js",
                code: code
              }
            ];
            if (self.isComplress) {
              files.push({
                path: "" + this.local.basename + ".min.js",
                code: self.compress(code)
              });
            }
            return this.next(files);
          }
        }
      }), Relay.each(Relay.serial(Relay.func(function(file) {
        this.local.filename = path.join(self.dstDir, file.path);
        return fs.writeFile(this.local.filename, file.code, this.next);
      }), Relay.func(function(err) {
        if (err != null) {
          console.log(err);
          return this.skip();
        } else {
          console.log("" + (self.timeStamp()) + " Write file: " + this.local.filename);
          return this.next();
        }
      }))))), Relay.func(function() {
        console.log("" + (self.timeStamp()) + " Complete compiling.");
        return this.next();
      })).complete(self.test).start();
    };

    CoffeeMill.prototype.compress = function(code) {
      return uglify.ast_squeeze(uglify.ast_mangle(parser.parse(code)));
    };

    CoffeeMill.prototype.test = function() {
      var self;
      self = this;
      return Relay.serial(Relay.func(function() {
        return fs.stat(self.testDir, this.next);
      }), Relay.func(function(err, stats) {
        var nodeunit;
        if (err == null) {
          console.log("" + (self.timeStamp()) + " Start testing.");
          nodeunit = spawn('nodeunit', [self.testDir]);
          nodeunit.stderr.setEncoding('utf8');
          nodeunit.stderr.on('data', function(data) {
            return console.log(data.replace(/\s*$/, ''));
          });
          nodeunit.stdout.setEncoding('utf8');
          nodeunit.stdout.on('data', function(data) {
            return console.log(data.replace(/\s*$/, ''));
          });
          nodeunit.on('exit', function(code) {
            return console.log("" + (self.timeStamp()) + " Complete testing.");
          });
        }
        return this.next();
      })).start();
    };

    return CoffeeMill;

  })();

}).call(this);