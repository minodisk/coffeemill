(function() {
  var R_ENV, Relay, beautify, coffee, colors, compile, error, fs, getFiles, info, minify, onDirChanged, padLeft, parser, path, runCommand, spawn, startCompile, startWatch, stdout, test, timeStamp, uglify, watch, write, _ref;
  fs = require("fs");
  path = require("path");
  spawn = require("child_process").spawn;
  coffee = require("coffee-script");
  _ref = require("uglify-js"), parser = _ref.parser, uglify = _ref.uglify;
  Relay = require("relay").Relay;
  colors = require("colors");
  R_ENV = /#if\s+BROWSER([\s\S]*?)(#else[\s\S]*?)?#endif/g;
  info = function(log) {
    return stdout("info", "cyan", log);
  };
  error = function(log) {
    return stdout("error", "red", log);
  };
  stdout = function(prefix, prefixColor, log) {
    var indent, len;
    indent = "";
    len = 10 + prefix.length;
    while (len--) {
      indent += " ";
    }
    log = typeof log.toString === "function" ? log.toString().replace(/\n+/g, "\n" + indent) : void 0;
    return console.log("" + prefix[prefixColor].inverse + " " + timeStamp().grey + " " + log);
  };
  exports.version = function() {
    var pkg;
    pkg = JSON.parse(fs.readFileSync(path.join(__dirname, "../package.json"), "utf8"));
    return pkg.version;
  };
  exports.grind = function(opts, callback) {
    if (opts.input == null) opts.input = "src";
    if (opts.output == null) opts.output = "lib";
    path.normalize(opts.input);
    path.normalize(opts.output);
    if (opts.test != null) path.normalize(opts.test);
    if (opts.silent) stdout = function() {};
    opts.requested = false;
    opts.callback = callback;
    info("input directory : " + String(opts.input).bold + "\noutput directory: " + String(opts.output).bold + "\njoin files to   : " + String(opts.join).bold + "\nminify          : " + String(opts.minify).bold + "\nbare            : " + String(opts.bare).bold + "\ntest directory  : " + String(opts.test).bold + "\nrun             : " + String(opts.run).bold + "\nsilent          : " + String(opts.silent).bold);
    return Relay.serial(Relay.func(function() {
      return startWatch(opts, this.next);
    }), Relay.func(function() {
      startCompile(opts);
      return this.next();
    })).start();
  };
  startWatch = function(opts, callback) {
    var dirs;
    dirs = [ opts.input ];
    if (opts.test) dirs.push(opts.test);
    Relay.each(Relay.func(function(dir) {
      return watch(dir, opts, this.next);
    })).complete(callback).start(dirs);
  };
  watch = function(dir, opts, callback) {
    Relay.serial(Relay.func(function() {
      return fs.stat(dir, this.next);
    }), Relay.func(function(err, stats) {
      if (err != null) {
        return this.skip();
      } else {
        if (!stats.isDirectory()) {
          return this.skip();
        } else {
          info("start watching directory: " + String(dir).bold);
          fs.watch(dir, function(event, filename) {
            return onDirChanged(opts);
          });
          return fs.readdir(dir, this.next);
        }
      }
    }), Relay.func(function(err, files) {
      if (err != null) {
        return this.skip();
      } else {
        return this.next(files);
      }
    }), Relay.each(Relay.func(function(file) {
      return watch(path.join(dir, file), opts, this.next);
    }))).complete(callback).start();
  };
  onDirChanged = function(opts) {
    if (!opts.requested) {
      info("detect changed");
      opts.requested = true;
      setTimeout(function() {
        opts.requested = false;
        return startCompile(opts);
      }, 1e3);
    }
  };
  getFiles = function(dir, callback) {
    return Relay.serial(Relay.func(function() {
      this.global.files = [];
      return fs.readdir(dir, this.next);
    }), Relay.func(function(err, files) {
      if (err != null) {
        return this.skip();
      } else {
        return this.next(files);
      }
    }), Relay.each(Relay.serial(Relay.func(function(file) {
      this.local.file = path.join(dir, file);
      return fs.stat(this.local.file, this.next);
    }), Relay.func(function(err, stats) {
      if (err != null) {
        return this.skip();
      } else if (stats.isDirectory()) {
        return getFiles(this.local.file, this.next);
      } else if (stats.isFile()) {
        return this.next([ this.local.file ]);
      } else {
        return this.skip();
      }
    }), Relay.func(function(files) {
      this.global.files = this.global.files.concat(files);
      return this.next();
    })), true)).complete(function() {
      return callback(this.global.files);
    }).start();
  };
  write = function(filename, data, callback) {
    return Relay.serial(Relay.func(function() {
      var dirs;
      dirs = filename.split("/");
      this.global.filename = "";
      return this.next(dirs);
    }), Relay.each(Relay.func(function(dir, i, dirs) {
      this.global.filename = path.join(this.global.filename, dir);
      if (i !== dirs.length - 1) {
        return fs.mkdir(this.global.filename, this.next);
      } else {
        return fs.writeFile(this.global.filename, data, this.next);
      }
    }), true)).complete(callback).start();
  };
  compile = function(code, opts, filepath, callback) {
    return Relay.serial(Relay.func(function() {
      var browser, compileOpts, details, node;
      compileOpts = {};
      if (opts.bare) compileOpts.bare = opts.bare;
      if (R_ENV.test(code)) {
        node = code.replace(R_ENV, function(matched, $1, $2, offset, source) {
          if ($2 != null) {
            return $2;
          } else {
            return "";
          }
        });
        node = coffee.compile(node, compileOpts);
        browser = code.replace(R_ENV, function(matched, $1, $2, offset, source) {
          if ($1 != null) {
            return $1;
          } else {
            return "";
          }
        });
        browser = coffee.compile(browser, compileOpts);
        details = [ {
          path: "node/" + filepath + ".js",
          code: beautify(node)
        }, {
          path: "browser/" + filepath + ".js",
          code: beautify(browser)
        } ];
        if (opts.minify) {
          details.push({
            path: "browser/" + filepath + ".min.js",
            code: minify(browser)
          });
        }
        return this.next(details);
      } else {
        code = coffee.compile(code, compileOpts);
        details = [ {
          path: "" + filepath + ".js",
          code: beautify(code)
        } ];
        if (opts.minify) {
          details.push({
            path: "" + filepath + ".min.js",
            code: minify(code)
          });
        }
        return this.next(details);
      }
    }), Relay.each(Relay.serial(Relay.func(function(detail) {
      this.local.filename = path.join(opts.output, detail.path);
      return write(this.local.filename, detail.code, this.next);
    }), Relay.func(function() {
      info("write file: " + String(this.local.filename).bold);
      return this.next();
    })))).complete(callback).start();
  };
  startCompile = function(opts) {
    Relay.serial(Relay.func(function() {
      info("start compiling".cyan.bold);
      return fs.stat(opts.output, this.next);
    }), Relay.func(function(err, stats) {
      if (err != null) {
        return error("'" + opts.output + "' does'nt exist");
      } else {
        return getFiles(opts.input, this.next);
      }
    }), function() {
      if (opts.join != null) {
        return Relay.serial(Relay.func(function(files) {
          this.global.details = [];
          return this.next(files);
        }), Relay.each(Relay.serial(Relay.func(function(file) {
          this.local.detail = {
            file: file
          };
          this.global.details.push(this.local.detail);
          return fs.readFile(this.local.detail.file, "utf8", this.next);
        }), Relay.func(function(err, code) {
          var i, token, tokens, _len;
          if (err != null) {
            return this.skip();
          } else {
            this.local.detail.code = code;
            tokens = coffee.tokens(this.local.detail.code);
            for (i = 0, _len = tokens.length; i < _len; i++) {
              token = tokens[i];
              switch (token[0]) {
               case "CLASS":
                if (this.local.detail["class"] == null) {
                  this.local.detail["class"] = tokens[i + 1][1];
                }
                break;
               case "EXTENDS":
                if (this.local.detail.depends == null) {
                  this.local.detail.depends = tokens[i + 1][1];
                }
              }
            }
            return this.next();
          }
        })), true), Relay.func(function() {
          var code, counter, d, detail, details, displace, i, internal, sorted, tmp, _i, _j, _k, _l, _len, _len2, _len3, _len4, _len5, _m;
          details = this.global.details;
          for (_i = 0, _len = details.length; _i < _len; _i++) {
            detail = details[_i];
            internal = false;
            for (_j = 0, _len2 = details.length; _j < _len2; _j++) {
              d = details[_j];
              if (d !== detail) {
                if (detail.depends === d["class"]) {
                  internal = true;
                  break;
                }
              }
            }
            if (!internal) detail.depends = null;
          }
          sorted = [];
          counter = 0;
          while (i = details.length) {
            if (counter++ === 100) throw new Error("Can't resolve dependency.");
            tmp = [];
            while (i--) {
              detail = details[i];
              displace = false;
              if (detail.depends == null) {
                displace = true;
              } else {
                for (_k = 0, _len3 = sorted.length; _k < _len3; _k++) {
                  d = sorted[_k];
                  if (detail.depends === d["class"]) {
                    displace = true;
                    break;
                  }
                }
              }
              if (displace) {
                details.splice(i, 1);
                tmp.push(detail);
              }
            }
            tmp.reverse();
            sorted = sorted.concat(tmp);
          }
          details = sorted;
          code = "";
          if (opts.bare != null) {
            for (_l = 0, _len4 = details.length; _l < _len4; _l++) {
              detail = details[_l];
              code += detail.code;
            }
          } else {
            for (_m = 0, _len5 = details.length; _m < _len5; _m++) {
              detail = details[_m];
              code += "" + detail.code + "\n";
            }
          }
          return compile(code, opts, opts.join, this.next);
        }));
      } else {
        return Relay.each(Relay.serial(Relay.func(function(file) {
          var basename, i, input, p, tmp;
          basename = path.basename(file, path.extname(file));
          tmp = path.join(file, "..", basename);
          input = opts.input.split("/");
          tmp = tmp.split("/");
          p = [];
          i = tmp.length;
          while (i-- && tmp[i] !== input[i]) {
            p.unshift(tmp[i]);
          }
          this.local.path = p.join("/");
          return fs.readFile(file, "utf8", this.next);
        }), Relay.func(function(err, code) {
          if (err != null) {
            return this.skip();
          } else {
            return compile(code, opts, this.local.path, this.next);
          }
        })));
      }
    }(), Relay.func(function() {
      info("complete compiling".cyan.bold);
      return this.next();
    })).complete(function() {
      if (opts.test != null) {
        return test(opts);
      } else if (opts.run != null) {
        return runCommand(opts);
      } else {
        return typeof opts.callback === "function" ? opts.callback() : void 0;
      }
    }).start();
  };
  minify = function(code) {
    return uglify.gen_code(uglify.ast_squeeze(uglify.ast_mangle(parser.parse(code))));
  };
  beautify = function(code) {
    return uglify.gen_code(parser.parse(code), {
      beautify: true,
      indent_start: 0,
      indent_level: 2
    });
  };
  test = function(opts) {
    Relay.func(function() {
      var nodeunit, _this = this;
      info("start testing".cyan.bold);
      nodeunit = spawn("nodeunit", [ opts.test ]);
      nodeunit.stderr.setEncoding("utf8");
      nodeunit.stderr.on("data", function(data) {
        return error(data.replace(/^\s*/, "").replace(/\s*$/, ""));
      });
      nodeunit.stdout.setEncoding("utf8");
      nodeunit.stdout.on("data", function(data) {
        return info(data.replace(/^\s*/, "").replace(/\s*$/, ""));
      });
      return nodeunit.on("exit", function(code) {
        info("complete testing".cyan.bold);
        return _this.next();
      });
    }).complete(function() {
      if (opts.run != null) {
        return runCommand(opts);
      } else {
        return typeof opts.callback === "function" ? opts.callback() : void 0;
      }
    }).start();
  };
  runCommand = function(opts) {
    Relay.func(function() {
      var commands, nodeunit, _this = this;
      info("" + "running command".cyan.bold + ": " + opts.run.bold);
      commands = opts.run.split(/\s+/);
      nodeunit = spawn(commands.shift(), commands);
      nodeunit.stderr.setEncoding("utf8");
      nodeunit.stderr.on("data", function(data) {
        return error(data.replace(/^\s*/, "").replace(/\s*$/, ""));
      });
      nodeunit.stdout.setEncoding("utf8");
      nodeunit.stdout.on("data", function(data) {
        return info(data.replace(/^\s*/, "").replace(/\s*$/, ""));
      });
      return nodeunit.on("exit", function(code) {
        info("complete running command".cyan.bold);
        return _this.next();
      });
    }).complete(function() {
      return typeof opts.callback === "function" ? opts.callback() : void 0;
    }).start();
  };
  timeStamp = function() {
    var date;
    date = new Date;
    return "" + padLeft(date.getHours()) + ":" + padLeft(date.getMinutes()) + ":" + padLeft(date.getSeconds());
  };
  padLeft = function(num, length, pad) {
    var str;
    if (length == null) length = 2;
    if (pad == null) pad = "0";
    str = num.toString(10);
    while (str.length < length) {
      str = pad + str;
    }
    return str;
  };
}).call(this);