(function() {
  var CoffeeMill, Deferred, EventEmitter, coffee, fs, path, pkg, spawn, uglify,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  path = require('path');

  fs = require('fs');

  spawn = require('child_process').spawn;

  EventEmitter = require('events').EventEmitter;

  coffee = require('coffee-script');

  Deferred = require('jsdeferred').Deferred;

  uglify = require('uglify-js');

  pkg = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'package.json')));

  CoffeeMill = (function(_super) {
    var EXT_NAMES;

    __extends(CoffeeMill, _super);

    EXT_NAMES = ['.coffee'];

    CoffeeMill.rTagVersion = /^v?([0-9\.]+)$/;

    CoffeeMill.rDocComment = /\/\*\*([\s\S]+?)\*\/\s*(.*)/g;

    CoffeeMill.rParam = /@param\s+{?(\S+?)}?\s+(\S+)\s+(.*)/g;

    CoffeeMill.rReturn = /@return\s+{?(\S+?)}?\s+(.*)/g;

    CoffeeMill.rCompletelyBlank = /^\s*$/;

    CoffeeMill.rLineEndSpace = /[ \t]+$/g;

    CoffeeMill.rBreak = /[\r\n]{3,}/g;

    function CoffeeMill(options) {
      this.options = options;
      this.changed = __bind(this.changed, this);
      CoffeeMill.__super__.constructor.call(this);
      if (options.input == null) {
        options.input = ['src'];
      }
      if (options.output == null) {
        options.output = ['lib'];
      }
      if (options.name == null) {
        options.name = 'main';
      }
      if (options.ver == null) {
        options.ver = '';
      }
      if ((options.js == null) && (options.uglify == null) && (options.coffee == null) && (options.map == null)) {
        options.js = true;
      }
    }

    CoffeeMill.prototype.changed = function() {
      var _this = this;
      clearTimeout(this.timeoutId);
      return this.timeoutId = setTimeout(function() {
        return _this.run();
      }, 500);
    };

    CoffeeMill.prototype.run = function() {
      this.scanInput();
      this.compile();
      return this;
    };

    CoffeeMill.prototype.scanInput = function() {
      var watcher, _i, _len, _ref;
      if (this.watchers != null) {
        _ref = this.watchers;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          watcher = _ref[_i];
          watcher.close();
        }
      }
      this.watchers = [];
      this.hasError = false;
      this.files = this.findFiles(this.options.input, this.options.watch ? this.changed : null);
      return this;
    };

    CoffeeMill.prototype.findFiles = function(dirs, change, basedir, files) {
      var childs, className, code, dir, dirPath, err, extendsClassName, extname, file, filePath, filename, i, isBasedir, name, namespace, namespaces, packages, r, stats, _i, _j, _len, _len1;
      if (files == null) {
        files = [];
      }
      isBasedir = basedir != null;
      for (_i = 0, _len = dirs.length; _i < _len; _i++) {
        dir = dirs[_i];
        if (isBasedir) {
          dirPath = dir;
        } else {
          dirPath = basedir = dir;
        }
        stats = fs.statSync(dirPath);
        if (stats.isFile()) {
          filePath = dirPath;
          if (EXT_NAMES.indexOf(path.extname(filePath)) !== -1) {
            packages = path.relative(basedir, filePath).split(path.sep);
            packages.pop();
            filename = path.basename(filePath);
            extname = path.extname(filePath);
            name = path.basename(filePath, extname);
            className = extendsClassName = null;
            code = fs.readFileSync(filePath, 'utf8');
            if (extname === '.coffee') {
              try {
                coffee.compile(code);
              } catch (_error) {
                err = _error;
                this.hasError = true;
                this.reportCompileError(filename, code, err);
              }
            }
            r = code.match(/class\s+(\S+)(?:\s+extends\s+(\S+))?/m);
            if (r != null) {
              r[0], className = r[1], extendsClassName = r[2];
            }
            namespaces = packages.concat([name]);
            namespace = namespaces.join('.');
            if ((className != null) && className !== namespace) {
              this.emit('warn', "class name isn't '" + namespace + "' (" + filePath + ")");
            }
            files.push({
              filePath: filePath,
              extname: extname,
              packages: packages,
              name: name,
              namespaces: namespaces,
              namespace: namespace,
              className: className,
              extendsClassName: extendsClassName,
              code: code
            });
          }
        } else if (stats.isDirectory()) {
          if (change != null) {
            this.watchers.push(fs.watch(dirPath, change));
          }
          childs = fs.readdirSync(dirPath);
          for (i = _j = 0, _len1 = childs.length; _j < _len1; i = ++_j) {
            file = childs[i];
            childs[i] = path.join(dirPath, file);
          }
          this.findFiles(childs, change, basedir, files);
        }
      }
      return files;
    };

    CoffeeMill.prototype.compile = function() {
      var cs, csName,
        _this = this;
      if (this.hasError) {
        return;
      }
      cs = '';
      csName = '';
      Deferred.next(function() {
        switch (_this.options.ver) {
          case 'none':
            return '';
          case 'gitTag':
            return _this.gitTag();
          default:
            return _this.options.ver;
        }
      }).error(function(err) {
        return _this.emit('error', 'fail to fetch version');
      }).next(function(version) {
        var classFiles, className, classNames, code, codes, counter, cwd, data, exp, exports, exportsCodes, ext, extendsClassName, file, filename, i, j, js, k, len, map, name, namespace, normalFiles, outputDir, outputPath, outputs, packageNamespace, packages, postfix, resolvedFiles, type, uglified, v, _i, _j, _k, _l, _len, _len1, _len2, _len3, _len4, _len5, _len6, _len7, _m, _n, _o, _p, _ref, _ref1, _ref2, _ref3, _ref4, _ref5;
        if (version !== '') {
          postfix = "-" + version;
        } else {
          postfix = '';
        }
        normalFiles = [];
        classFiles = [];
        classNames = [];
        resolvedFiles = [];
        _ref = _this.files;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          file = _ref[_i];
          if (file.className != null) {
            classFiles.push(file);
            classNames.push(file.className);
          } else {
            normalFiles.push(file);
          }
        }
        i = classFiles.length;
        while (i--) {
          extendsClassName = classFiles[i].extendsClassName;
          if ((extendsClassName == null) || classNames.indexOf(extendsClassName) === -1) {
            resolvedFiles.unshift(classFiles.splice(i, 1)[0]);
          }
        }
        while (i = classFiles.length) {
          while (i--) {
            extendsClassName = classFiles[i].extendsClassName;
            for (j = _j = 0, _len1 = resolvedFiles.length; _j < _len1; j = ++_j) {
              className = resolvedFiles[j].className;
              if (className === extendsClassName) {
                resolvedFiles.splice(j + 1, 0, classFiles.splice(i, 1)[0]);
                break;
              }
            }
          }
        }
        _this.files = normalFiles.concat(resolvedFiles);
        codes = [];
        exports = {};
        _ref1 = _this.files;
        for (_k = 0, _len2 = _ref1.length; _k < _len2; _k++) {
          _ref2 = _ref1[_k], code = _ref2.code, name = _ref2.name, className = _ref2.className, packages = _ref2.packages, namespace = _ref2.namespace;
          codes.push(code);
          exp = exports;
          for (_l = 0, _len3 = packages.length; _l < _len3; _l++) {
            packageNamespace = packages[_l];
            if (exp[packageNamespace] == null) {
              exp[packageNamespace] = {};
            }
            exp = exp[packageNamespace];
          }
        }
        exportsCodes = [];
        exportsCodes.push("___exports = if module?.exports? then module.exports else if window? then window else {}\n___extend = (child, parent) ->\n  for key, val of parent\n    continue unless Object::hasOwnProperty.call parent, key\n    if Object::toString.call(val) is '[object Object]'\n      child[key] = {}\n      ___extend child[key], val\n    else\n      child[key] = val");
        for (k in exports) {
          v = exports[k];
          exportsCodes.push("___exports." + k + " ?= {}\n" + k + " = ___exports." + k + "\n___extend " + k + ", " + (JSON.stringify(v)));
        }
        cs = exportsCodes.concat(codes.map(function(code) {
          return code.replace(/class\s+(\S+)/g, '___exports.$1 = class $1');
        })).join('\n\n');
        csName = "" + _this.options.name + postfix + ".coffee";
        outputs = [];
        if (_this.options.coffee) {
          outputs.push({
            type: 'coffee',
            filename: csName,
            data: cs
          });
        }
        if (_this.options.map) {
          _ref3 = coffee.compile(cs, {
            sourceMap: true,
            generatedFile: "" + _this.options.name + postfix + ".js",
            sourceRoot: '',
            sourceFiles: ["" + _this.options.name + postfix + ".coffee"]
          }), js = _ref3.js, map = _ref3.v3SourceMap;
        } else {
          js = coffee.compile(cs);
        }
        if (_this.options.js) {
          if (map != null) {
            js += "\n/*\n//@ sourceMappingURL=" + _this.options.name + postfix + ".map\n*/";
          }
          outputs.push({
            type: 'js',
            filename: "" + _this.options.name + postfix + ".js",
            data: js
          });
        }
        if (map != null) {
          outputs.push({
            type: 'source map',
            filename: "" + _this.options.name + postfix + ".map",
            data: map
          });
        }
        if (_this.options.uglify) {
          uglified = uglify.minify(js, {
            fromString: true
          }).code;
          if (postfix === '') {
            ext = '-min.js';
          } else {
            ext = '.min.js';
          }
          outputs.push({
            type: 'uglify',
            filename: "" + _this.options.name + postfix + ext,
            data: uglified
          });
        }
        len = 0;
        for (_m = 0, _len4 = outputs.length; _m < _len4; _m++) {
          type = outputs[_m].type;
          len = Math.max(len, type.length);
        }
        for (i = _n = 0, _len5 = outputs.length; _n < _len5; i = ++_n) {
          type = outputs[i].type;
          while (type.length < len) {
            type += ' ';
          }
          outputs[i].type = type;
        }
        cwd = process.cwd();
        counter = 0;
        _ref4 = _this.options.output;
        for (_o = 0, _len6 = _ref4.length; _o < _len6; _o++) {
          outputDir = _ref4[_o];
          outputDir = path.resolve(cwd, outputDir);
          if (!fs.existsSync(outputDir)) {
            fs.mkdirSync(outputDir);
          }
          for (_p = 0, _len7 = outputs.length; _p < _len7; _p++) {
            _ref5 = outputs[_p], type = _ref5.type, filename = _ref5.filename, data = _ref5.data;
            outputPath = path.resolve(cwd, path.join(outputDir, filename));
            fs.writeFileSync(outputPath, data, 'utf8');
            _this.emit('created', path.relative('.', outputPath));
            counter++;
          }
        }
        return _this.emit('complete', counter);
      }).error(function(err) {
        if (err.location != null) {
          return _this.reportCompileError(csName, cs, err);
        } else {
          return _this.emit('error', "" + err.stack);
        }
      });
      return this;
    };

    CoffeeMill.prototype.reportCompileError = function(csName, cs, err) {
      var code, first_column, first_line, last_column, last_line, lineNumber, lines, mark, nextLineNumber, _ref;
      if (err.location != null) {
        _ref = err.location, first_line = _ref.first_line, first_column = _ref.first_column, last_line = _ref.last_line, last_column = _ref.last_column;
        lines = cs.split(/\r?\n/);
        code = lines.splice(first_line, 1);
        if (first_line !== last_line) {
          last_line = first_line;
          last_column = code.length - 1;
        }
        if (last_column <= first_column) {
          last_column = first_column;
        }
        mark = '';
        while (mark.length < first_column) {
          mark += ' ';
        }
        while (mark.length <= last_column) {
          mark += '^';
        }
        lineNumber = '' + first_line;
        nextLineNumber = '';
        while (nextLineNumber.length < lineNumber.length) {
          nextLineNumber += ' ';
        }
        return this.emit('error', "CoffeeScript compile error\n" + csName + ":" + first_line + ":" + first_column + "\n" + (lineNumber + '.') + code + "\n" + (nextLineNumber + '.') + mark);
      } else {
        return this.emit('error', "CoffeeScript compile error\n" + err);
      }
    };

    CoffeeMill.prototype.indent = function(code) {
      var i, line, lines, _i, _len;
      lines = code.split(/\r?\n/g);
      for (i = _i = 0, _len = lines.length; _i < _len; i = ++_i) {
        line = lines[i];
        lines[i] = '  ' + line;
      }
      return lines.join('\n');
    };

    CoffeeMill.prototype.gitTag = function() {
      var d, err, gitTag, out;
      d = new Deferred();
      gitTag = spawn('git', ['tag']);
      out = '';
      gitTag.stdout.setEncoding('utf8');
      gitTag.stdout.on('data', function(data) {
        return out += data;
      });
      err = '';
      gitTag.stderr.setEncoding('utf8');
      gitTag.stderr.on('data', function(data) {
        return err += data.red;
      });
      gitTag.on('close', function() {
        var i, minor, r, tag, tags, versions;
        if (err !== '') {
          return d.fail(err);
        }
        tags = out.split('\n');
        i = tags.length;
        while (i--) {
          tag = tags[i];
          r = tag.match(CoffeeMill.rTagVersion);
          if ((r != null ? r[1] : void 0) == null) {
            continue;
          }
          versions = r[1].split('.');
          minor = parseInt(versions[versions.length - 1], 10);
          versions[versions.length - 1] = minor + 1;
          d.call(versions.join('.'));
          return;
        }
        return d.fail('no tag as version');
      });
      return d;
    };

    return CoffeeMill;

  })(EventEmitter);

  module.exports = {
    CoffeeMill: CoffeeMill,
    run: function() {
      var commander, list, util;
      util = require('util');
      commander = require('commander');
      list = function(val) {
        return val.split(',');
      };
      commander.version(pkg.version).usage('[options]').option('-i, --input <dirnames>', 'output directory (defualt is \'src\')', list, ['src']).option('-o, --output <dirnames>', 'output directory (defualt is \'lib\')', list, ['lib']).option('-n, --name [basename]', 'output directory (defualt is \'main\')', 'main').option('-v, --ver <version>', 'file version: supports version string, \'gitTag\' or \'none\' (default is \'\')', '').option('-j, --js', 'write JavaScript file (.js)', true).option('-u, --uglify', 'write uglified JavaScript file (.min.js)').option('-c, --coffee', 'write CoffeeScript file (.coffee)').option('-m, --map', 'write source maps file JavaScript to CoffeeScript (.map)').option('-w, --watch', 'watch the change of input directory recursively').parse(process.argv);
      return new CoffeeMill(commander).on('warn', function(message) {
        return util.puts(message);
      }).on('error', function(message) {
        return util.error(message);
      }).on('created', function(filepath) {
        return util.puts("File " + filepath + " created");
      }).on('complete', function(filenum) {
        return util.puts("Done without errors");
      }).run();
    }
  };

}).call(this);
