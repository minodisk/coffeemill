(function() {
  var Markdown, R_ENV, Relay, beautify, coffee, colors, compile, error, fs, generateDoc, generateIndexDoc, getComment, getFilepath, getFiles, info, jade, minify, onDirChanged, padLeft, parser, path, runCommand, sorter, spawn, startCompile, startWatch, stdout, test, timeStamp, uglify, watch, write, _ref;
  fs = require("fs");
  path = require("path");
  spawn = require("child_process").spawn;
  coffee = require("coffee-script");
  _ref = require("uglify-js"), parser = _ref.parser, uglify = _ref.uglify;
  Relay = require("relay").Relay;
  colors = require("colors");
  jade = require("jade");
  Markdown = require("node-markdown").Markdown;
  sorter = require("sorter");
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
    info("input dir       : " + String(opts.input).bold + "\noutput dir      : " + String(opts.output).bold + "\njoin files to   : " + String(opts.join).bold + "\nminify          : " + String(opts.minify).bold + "\nbare            : " + String(opts.bare).bold + "\ndocs output dir : " + String(opts.docs).bold + "\ndocs template   : " + String(opts.template).bold + "\ntest directory  : " + String(opts.test).bold + "\nrun             : " + String(opts.run).bold + "\nsilent          : " + String(opts.silent).bold);
    return Relay.serial(Relay.func(function() {
      if (opts.template != null) {
        return fs.readFile(opts.template, "utf8", this.next);
      } else {
        return this.next();
      }
    }), Relay.func(function(err, template) {
      if (err != null) {
        throw err;
        this.skip();
      } else {
        opts.compiler = jade.compile(template, {
          filename: "templates/docs.jade",
          pretty: true
        });
      }
      return this.next();
    }), Relay.func(function() {
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
  write = function(filename, code, callback) {
    return Relay.serial(Relay.func(function() {
      var dirs;
      dirs = filename.split("/");
      this.global.filename = "";
      return this.next(dirs);
    }), Relay.each(Relay.serial(Relay.func(function(dir, i, dirs) {
      filename = this.global.filename = path.join(this.global.filename, dir);
      if (i !== dirs.length - 1) {
        return fs.mkdir(filename, this.next);
      } else {
        return fs.writeFile(filename, code, this.next);
      }
    }), Relay.func(function(err) {
      if (err == null) info("write file: " + String(this.global.filename).bold);
      return this.next();
    })))).complete(function() {
      return typeof callback === "function" ? callback() : void 0;
    }).start();
  };
  getFilepath = function(filename, dir) {
    var basename, i, input, p, tmp;
    basename = path.basename(filename, path.extname(filename));
    tmp = path.join(filename, "..", basename);
    input = dir.split("/");
    tmp = tmp.split("/");
    p = [];
    i = tmp.length;
    while (i-- && tmp[i] !== input[i]) {
      p.unshift(tmp[i]);
    }
    return p.join("/");
  };
  getComment = function(value) {
    var $, doc, key, line, _i, _len, _ref2;
    doc = {
      texts: []
    };
    _ref2 = value.split(/\n|\r\n?/);
    for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
      line = _ref2[_i];
      if (($ = line.match(/^@(\w+)\s+(.*)?/)) && (key = $[1])) {
        if (!doc[key]) doc[key] = [];
        switch (key) {
         case "param":
         case "property":
          if ($ = $[2].match(/^(\w+)\s+(\w+)\s+(.*)/)) {
            doc[key].push({
              name: $[1],
              type: $[2],
              text: $[3]
            });
          }
          break;
         case "returns":
          if ($ = $[2].match(/^(\w+)\s+(.*)/)) {
            doc[key] = {
              type: $[1],
              text: $[2]
            };
          }
          break;
         case "type":
          if ($ = $[2].match(/^(\w+)/)) {
            doc[key].push({
              type: $[1]
            });
          }
        }
      } else if (line !== "") {
        doc.texts.push(line);
      }
    }
    doc.text = Markdown(doc.texts.join("\n"));
    return doc;
  };
  generateDoc = function(code, opts, filepath, callback) {
    var comment, data, doc, docs, head, i, idTokens, indent, key, obj, param, prevToken, token, tokens, type, value, _i, _j, _len, _len2, _len3, _ref2;
    if (path.basename(filepath).charAt(0) === "_") {
      if (typeof callback === "function") callback();
      return;
    }
    head = {};
    docs = [];
    indent = 0;
    param = false;
    idTokens = [];
    comment = null;
    tokens = coffee.tokens(code);
    for (i = 0, _len = tokens.length; i < _len; i++) {
      token = tokens[i];
      type = token[0], value = token[1];
      token = {
        type: type,
        value: value
      };
      switch (type) {
       case "INDENT":
        indent++;
        break;
       case "OUTDENT":
        indent--;
        break;
       case "PARAM_START":
        param = true;
        break;
       case "PARAM_END":
        param = false;
      }
      switch (indent) {
       case 0:
        switch (type) {
         case "HERECOMMENT":
          if (value.charAt(0) === "*") {
            _ref2 = getComment(value.substr(1));
            for (key in _ref2) {
              value = _ref2[key];
              head[key] = value;
            }
          }
          break;
         case "IDENTIFIER":
          idTokens.push(token);
          switch (typeof prevToken !== "undefined" && prevToken !== null ? prevToken.type : void 0) {
           case "CLASS":
            head["class"] = value;
            break;
           case "EXTENDS":
            head["extends"] = value;
          }
        }
        break;
       case 1:
        switch (type) {
         case "HERECOMMENT":
          if (value.charAt(0) === "*") comment = getComment(value.substr(1));
          break;
         case "IDENTIFIER":
          if (!param) {
            doc = {
              "static": prevToken.type === "@",
              type: "property",
              name: value,
              "private": value.charAt(0) === "_",
              returns: {
                type: "void"
              }
            };
            for (key in comment) {
              value = comment[key];
              doc[key] = value;
            }
            docs.push(doc);
            comment = null;
          }
          break;
         case "->":
         case "=>":
          doc.type = "function";
        }
      }
      if (i === tokens.length - 1 && !(head["class"] != null)) {
        head["class"] = idTokens[idTokens.length - 1].value;
        for (_i = 0, _len2 = docs.length; _i < _len2; _i++) {
          doc = docs[_i];
          doc.static = true;
        }
      }
      prevToken = token;
    }
    data = {
      head: head,
      "static": {
        properties: [],
        methods: []
      },
      constructor: null,
      member: {
        properties: [],
        methods: []
      },
      toParamString: function(param) {
        var name, params, _j, _len3, _ref3;
        if (param != null) {
          params = [];
          for (_j = 0, _len3 = param.length; _j < _len3; _j++) {
            _ref3 = param[_j], name = _ref3.name, type = _ref3.type;
            params.push("" + name + ":" + type);
          }
          return params.join(", ");
        } else {
          return "";
        }
      }
    };
    for (_j = 0, _len3 = docs.length; _j < _len3; _j++) {
      doc = docs[_j];
      if (doc.name === "constructor") {
        doc.name = head["class"];
        data.constructor = doc;
      } else {
        obj = doc.static ? data.static : data.member;
        if (doc.type === "function") {
          obj.methods.push(doc);
        } else {
          obj.properties.push(doc);
        }
      }
    }
    sorter.dictSort(data.static.properties, "name");
    sorter.dictSort(data.static.methods, "name");
    sorter.dictSort(data.member.properties, "name");
    sorter.dictSort(data.member.methods, "name");
    return Relay.serial(Relay.func(function() {
      this.local.filename = path.join(opts.docs, "" + filepath + ".html");
      return write(this.local.filename, opts.compiler(data), this.next);
    }), Relay.func(function() {
      return this.next();
    })).complete(function() {
      return typeof callback === "function" ? callback() : void 0;
    }).start();
  };
  generateIndexDoc = function(filepaths, opts, callback) {
    var filepath, html, name, package, packages, _i, _len;
    packages = {};
    sorter.dictSort(filepaths);
    for (_i = 0, _len = filepaths.length; _i < _len; _i++) {
      filepath = filepaths[_i];
      if (path.basename(filepath).charAt(0) !== "_") {
        package = filepath.split("/");
        name = package.pop();
        package = package.join(".");
        if (packages[package] == null) packages[package] = [];
        packages[package].push({
          name: name,
          url: "" + filepath + ".html"
        });
      }
    }
    console.log(packages);
    html = opts.compiler({
      packages: packages
    });
    return write(path.join(opts.docs, "index.html"), html, callback);
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
      return this.next();
    })))).complete(callback).start();
  };
  startCompile = function(opts) {
    Relay.serial(Relay.func(function() {
      info("start compiling".cyan.bold);
      this.global.filepaths = [];
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
          var filepath, i, token, tokens, _len;
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
            if (opts.compiler != null) {
              filepath = getFilepath(this.local.detail.file, opts.input);
              generateDoc(code, opts, filepath);
              this.global.filepaths.push(filepath);
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
          this.local.path = getFilepath(file, opts.input);
          return fs.readFile(file, "utf8", this.next);
        }), Relay.func(function(err, code) {
          if (err != null) {
            return this.skip();
          } else {
            compile(code, opts, this.local.path, this.next);
            if (opts.compiler != null) {
              generateDoc(code, opts, this.local.path);
              return this.global.filepaths.push(this.local.path);
            }
          }
        })));
      }
    }(), Relay.func(function() {
      return generateIndexDoc(this.global.filepaths, opts, this.next);
    }), Relay.func(function() {
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