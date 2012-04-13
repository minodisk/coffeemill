(function() {
  var R_ENV, Relay, coffee, colors, error, fs, info, minify, onDirChanged, padLeft, parser, path, runCommand, spawn, startCompile, startWatch, stdout, test, timeStamp, uglify, _ref;

  fs = require('fs');

  path = require('path');

  spawn = require('child_process').spawn;

  coffee = require('coffee-script');

  _ref = require('uglify-js'), parser = _ref.parser, uglify = _ref.uglify;

  Relay = require('relay').Relay;

  colors = require('colors');

  R_ENV = /#if\s+BROWSER([\s\S]*?)(#else[\s\S]*?)?#endif/g;

  info = function(log) {
    return stdout('info', 'cyan', log);
  };

  error = function(log) {
    return stdout('error', 'red', log);
  };

  stdout = function(prefix, prefixColor, log) {
    var indent, len;
    indent = '';
    len = 10 + prefix.length;
    while (len--) {
      indent += ' ';
    }
    log = typeof log.toString === "function" ? log.toString().replace(/\n+/g, "\n" + indent) : void 0;
    return console.log("" + prefix[prefixColor].inverse + " " + (timeStamp().grey) + " " + log);
  };

  exports.version = function() {
    var pkg;
    pkg = JSON.parse(fs.readFileSync(path.join(__dirname, '../package.json'), 'utf8'));
    return pkg.version;
  };

  exports.help = function() {
    return "Usage   : coffeemill [-o output_dir] [-t test_dir] [src_dir]\nOptions : -v, --version             display the version number\n          -h, --help                display this help message\n          -s, --silent              without displaying log\n          -j, --join [FILE]         concatenate the source CoffeeScript before compiling\n          -b, --bare                compile without a top-level function wrapper\n          -m, --minify              minify the compiled JavaScript\n          -o, --output [DIR]        set the output directory for compiled JavaScript (lib)\n          -t, --test [DIR]          set the test directory of nodeunit\n          -c, --command '[COMMAND]' run command after all processing is finished\nArgument: source directory (src)";
  };

  exports.grind = function(opts, callback) {
    if (opts.input == null) opts.input = 'src';
    if (opts.output == null) opts.output = 'lib';
    if (opts.silent) stdout = function() {};
    opts.requested = false;
    opts.callback = callback;
    info("input directory : " + (String(opts.input).bold) + "\noutput directory: " + (String(opts.output).bold) + "\ntest directory  : " + (String(opts.test).bold) + "\ncommand         : " + (String(opts.command).bold) + "\njoin files to   : " + (String(opts.join).bold) + "\nbare            : " + (String(opts.bare).bold) + "\nminify          : " + (String(opts.minify).bold) + "\nsilent          : " + (String(opts.silent).bold));
    return Relay.serial(Relay.func(function() {
      return startWatch(opts, this.next);
    }), Relay.func(function() {
      startCompile(opts);
      return this.next();
    })).start();
  };

  startWatch = function(opts, callback) {
    var dirs;
    dirs = [opts.input];
    if (opts.test) dirs.push(opts.test);
    Relay.each(Relay.serial(Relay.func(function(dir) {
      this.local.dir = dir;
      return fs.stat(dir, this.next);
    }), Relay.func(function(err, stats) {
      if (err == null) {
        info("start watching directory: " + (String(this.local.dir).bold));
        fs.watch(this.local.dir, function(event, filename) {
          return onDirChanged(opts);
        });
      }
      return this.next();
    }))).complete(function() {
      return typeof callback === "function" ? callback() : void 0;
    }).start(dirs);
  };

  onDirChanged = function(opts) {
    if (!opts.requested) {
      info("detect changed");
      opts.requested = true;
      setTimeout((function() {
        opts.requested = false;
        return startCompile(opts);
      }), 1000);
    }
  };

  startCompile = function(opts) {
    Relay.serial(Relay.func(function() {
      info("start compiling".cyan.bold);
      return fs.stat(opts.output, this.next);
    }), Relay.func(function(err, stats) {
      if (err != null) {
        return error("'" + opts.output + "' does'nt exist");
      } else {
        return fs.readdir(opts.input, this.next);
      }
    }), Relay.func(function(err, files) {
      if (err != null) {
        return error(err);
      } else {
        return this.next(files);
      }
    }), Relay.each(Relay.serial(Relay.func(function(file) {
      this.local.basename = path.basename(file, path.extname(file));
      return fs.readFile(path.join(opts.input, file), 'utf8', this.next);
    }), Relay.func(function(err, code) {
      var browser, compileOpts, files, node;
      if (err != null) {
        return this.skip();
      } else {
        compileOpts = {
          bare: opts.bare
        };
        if (typeof join !== "undefined" && join !== null) {
          compileOpts.join = this.join;
        }
        if (R_ENV.test(code)) {
          node = code.replace(R_ENV, function(matched, $1, $2, offset, source) {
            if ($2 != null) {
              return $2;
            } else {
              return '';
            }
          });
          node = coffee.compile(node, compileOpts);
          browser = code.replace(R_ENV, function(matched, $1, $2, offset, source) {
            if ($1 != null) {
              return $1;
            } else {
              return '';
            }
          });
          browser = coffee.compile(browser, compileOpts);
          files = [
            {
              path: "node/" + this.local.basename + ".js",
              code: node
            }, {
              path: "browser/" + this.local.basename + ".js",
              code: browser
            }
          ];
          if (opts.minify) {
            files.push({
              path: "browser/" + this.local.basename + ".min.js",
              code: minify(browser)
            });
          }
          return this.next(files);
        } else {
          code = coffee.compile(code, compileOpts);
          files = [
            {
              path: "" + this.local.basename + ".js",
              code: code
            }
          ];
          if (opts.minify) {
            files.push({
              path: "" + this.local.basename + ".min.js",
              code: minify(code)
            });
          }
          return this.next(files);
        }
      }
    }), Relay.each(Relay.serial(Relay.func(function(file) {
      this.local.filename = path.join(opts.output, file.path);
      return fs.writeFile(this.local.filename, file.code, this.next);
    }), Relay.func(function(err) {
      if (err != null) {
        error(err);
        return this.skip();
      } else {
        info("write file: " + (String(this.local.filename).bold));
        return this.next();
      }
    }))))), Relay.func(function() {
      info("complete compiling".cyan.bold);
      return this.next();
    })).complete(function() {
      if (opts.test != null) {
        return test(opts);
      } else if (opts.command != null) {
        return runCommand(opts);
      } else {
        return typeof opts.callback === "function" ? opts.callback() : void 0;
      }
    }).start();
  };

  minify = function(code) {
    return uglify.gen_code(uglify.ast_squeeze(uglify.ast_mangle(parser.parse(code))));
  };

  test = function(opts) {
    Relay.func(function() {
      var nodeunit,
        _this = this;
      info("start testing".cyan.bold);
      nodeunit = spawn('nodeunit', [opts.test]);
      nodeunit.stderr.setEncoding('utf8');
      nodeunit.stderr.on('data', function(data) {
        return error(data.replace(/^\s*/, '').replace(/\s*$/, ''));
      });
      nodeunit.stdout.setEncoding('utf8');
      nodeunit.stdout.on('data', function(data) {
        return info(data.replace(/^\s*/, '').replace(/\s*$/, ''));
      });
      return nodeunit.on('exit', function(code) {
        info("complete testing".cyan.bold);
        return _this.next();
      });
    }).complete(function() {
      if (opts.command != null) {
        return runCommand(opts);
      } else {
        return typeof opts.callback === "function" ? opts.callback() : void 0;
      }
    }).start();
  };

  runCommand = function(opts) {
    Relay.func(function() {
      var commands, nodeunit,
        _this = this;
      info("" + 'running command'.cyan.bold + ": " + opts.command.bold);
      commands = opts.command.split(/\s+/);
      nodeunit = spawn(commands.shift(), commands);
      nodeunit.stderr.setEncoding('utf8');
      nodeunit.stderr.on('data', function(data) {
        return error(data.replace(/^\s*/, '').replace(/\s*$/, ''));
      });
      nodeunit.stdout.setEncoding('utf8');
      nodeunit.stdout.on('data', function(data) {
        return info(data.replace(/^\s*/, '').replace(/\s*$/, ''));
      });
      return nodeunit.on('exit', function(code) {
        info("complete running command".cyan.bold);
        return _this.next();
      });
    }).complete(function() {
      return typeof opts.callback === "function" ? opts.callback() : void 0;
    }).start();
  };

  timeStamp = function() {
    var date;
    date = new Date();
    return "" + (padLeft(date.getHours())) + ":" + (padLeft(date.getMinutes())) + ":" + (padLeft(date.getSeconds()));
  };

  padLeft = function(num, length, pad) {
    var str;
    if (length == null) length = 2;
    if (pad == null) pad = '0';
    str = num.toString(10);
    while (str.length < length) {
      str = pad + str;
    }
    return str;
  };

}).call(this);
