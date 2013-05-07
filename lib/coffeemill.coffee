sys = require 'sys'
path = require 'path'
fs = require 'fs'
{ spawn } = require 'child_process'
{ Deferred } = require 'jsdeferred'
commander = require 'commander'
uglify = require 'uglify-js'
colors = require 'colors'
ejs = require 'ejs'
jade = require 'jade'
coffee = require 'coffee-script'


class CoffeeMill

  EXT_NAMES = [ '.coffee' ]

  @rTagVersion     : /^v?([0-9\.]+)$/
  @rDocComment     : /\/\*\*([\s\S]+?)\*\/\s*(.*)/g
  @rParam          : /@param\s+{?(\S+?)}?\s+(\S+)\s+(.*)/g
  @rReturn         : /@return\s+{?(\S+?)}?\s+(.*)/g
  @rCompletelyBlank: /^\s*$/
  @rLineEndSpace   : /[ \t]+$/g
  @rBreak          : /[\r\n]{3,}/g

  constructor: (@cwd) ->
    list = (val) ->
      val.split ','

    commander
      .version(JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'package.json'))).version)
      .usage('[options]')
      .option('-n, --name <basename>', 'output directory (defualt is \'\')', '')
      .option('-i, --input <dirnames>', 'output directory (defualt is \'src\')', list, 'src')
      .option('-o, --output <dirnames>', 'output directory (defualt is \'lib\')', list, 'lib')
      .option('-u, --uglify', 'minify with uglifyJS (.min.js)')
      .option('-m, --map', 'generate source maps (.map)')
      .option('-w, --watch', 'watch the change of input directory recursively')
      .option('-v, --ver <version>', 'file version: supports version string, \'gitTag\' or \'none\' (default is \'none\')', 'gitTag')
      .parse(process.argv)

    @scanInput()
    @compile()

  scanInput: ->
    watcher.close() for watcher in @watchers?
    @watchers = []
    @files = @findFiles commander.input, if commander.watch then @changed else null
#    fs.watch @makefile.jsdoc.template, @changed if @makefile.jsdoc?.template?

  findFiles: (dir, change, files = []) ->
    stats = fs.statSync dir
    if stats.isFile()
      # when extname is relevant, push filepath into result
      if EXT_NAMES.indexOf(path.extname dir) isnt -1
        files.push dir
    else if stats.isDirectory()
      # watch dir
      if change?
        @watchers.push fs.watch dir, change
      # recursively
      for file in fs.readdirSync dir
        @findFiles path.join(dir, file), change, files
    files

  changed: =>
    clearTimeout @timeoutId
    @timeoutId = setTimeout =>
      @scanInput()
      @compile()
    , 100

  compile: ->
    sys.puts new Date().toString().underline

    Deferred
      .next =>
        switch commander.ver
          when 'none'
            ''
          when 'gitTag'
            @gitTag()
          else
            commander.ver
      .error (err) =>
        ''
      .next (version) =>
        if version isnt ''
          sys.puts 'version: ' + version
          postfix = "-#{version}"
        else
          postfix = ''

        #        if @makefile.jsdoc
        #          @jsdoc()

        # find source files
        #        filePathes = @findFiles path.join @cwd, commander.input

        # 1. read code
        # 2. parse package name
        # 3. parse class name and dependent class name
        files = []
        for filePath in @files
          packages = path.relative(commander.input, filePath).split path.sep
          packages.pop()
          packageName = packages.join '.'

          extname = path.extname filePath
          name = path.basename filePath, extname

          code = fs.readFileSync filePath, 'utf8'
          r = code.match /class\s+(\w+)(?:\s+extends\s+(\w+))?/m
          if r?
            [ {},
              className,
              extendsName ] = r
          files.push
            filePath   : filePath
            extname    : extname
            packages   : packages
            name       : name
            extendsName: extendsName or ''
            code       : code

        # sort on dependency
        files.sort (a, b) ->
          if a.extendsName is ''
            -1
          else if b.extendsName is ''
            1
          else if b.extendsName is a.name
            -1
          else if a.extendsName is b.name
            1
          else
            0

        # 1. find package
        # 2. concat codes
        # 3. add exports
        codes = []
        exports = {}
        for file in files
          codes.push file.code
          exp = exports
          for pkg in file.packages
            exp[pkg] = {} unless exp[pkg]?
            exp = exp[pkg]
          exp[file.name] = file.name
        codes.push 'window[k] = v for k, v of ' + JSON.stringify(exports, null, 2).replace(/(:\s+)"(\w+)"/g, '$1$2')
        code = codes.join '\n\n'

        output = path.join @cwd, commander.output

        # Make output directory
        fs.mkdirSync output unless fs.existsSync output

        filename = "#{commander.name}#{postfix}.coffee"
        output = path.join @cwd, commander.output, filename
        fs.writeFileSync output, code, 'utf8'
        sys.puts 'concat    : '.cyan + output
        @copy code, filename

        { js: code, v3SourceMap } = @coffee code,
          sourceMap    : true
          generatedFile: "#{commander.name}#{postfix}.js"
          sourceRoot   : ''
          sourceFiles  : [ "#{commander.name}#{postfix}.coffee" ]
        if commander.map
          code += "\n/*\n//@ sourceMappingURL=#{commander.name}#{postfix}.map\n*/"
        filename = "#{commander.name}#{postfix}.js"
        output = path.join @cwd, commander.output, filename
        fs.writeFileSync output, code, 'utf8'
        sys.puts 'compile   : '.cyan + output
        @copy code, filename

        if commander.map
          filename = "#{commander.name}#{postfix}.map"
          output = path.join @cwd, commander.output, filename
          fs.writeFileSync output, v3SourceMap, 'utf8'
          sys.puts 'source map: '.cyan + output
          @copy code, filename

        if commander.uglify
          { code } = uglify.minify code, { fromString: true }
          filename = "#{commander.name}#{postfix}.min.js"
          output = path.join @cwd, commander.output, filename
          fs.writeFileSync output, code, 'utf8'
          sys.puts 'minify    : '.cyan + output
          @copy code, filename

        sys.puts 'complete!!'.green

      .error (err) ->
        sys.error err.stack

  copy: (code, filename) ->
    return unless commander.copy
    output = path.join commander.copy, filename
    fs.writeFileSync output, code, 'utf8'
    sys.puts 'copy      : '.cyan + output

  gitTag: ->
    d = new Deferred()
    gitTag = spawn 'git', [ 'tag' ]
    out = ''
    err = ''
    gitTag.stdout.setEncoding 'utf8'
    gitTag.stdout.on 'data', (data) ->
      out += data
    gitTag.stderr.setEncoding 'utf8'
    gitTag.stderr.on 'data', (data) ->
      err += data.red
    gitTag.on 'close', ->
      return d.fail err if err isnt ''
      tags = out.split '\n'
      i = tags.length
      while i--
        tag = tags[i]
        r = tag.match CoffeeMill.rTagVersion
        continue unless r? [ 1 ]?
        versions = r[1].split '.'
        minor = parseInt versions[versions.length - 1], 10
        versions[versions.length - 1] = minor + 1
        return d.call versions.join '.'
      d.fail 'no tag as version'
    d


  jsdoc: (wholeCode) ->
    if @makefile.jsdoc.src.files?
      files = @makefile.jsdoc.src.files
      for file, i in files
        files[i] = path.join @cwd, commander.input, file
      code = @concatFiles files
    else
      code = wholeCode

    properties = []
    while r = CoffeeMill.rDocComment.exec code
      comment = r[1]
      name = r[2]
      params = []
      returns = []
      comment = comment
        .replace(/^[ \t]*\/\/.*$/g, '')
        .replace(/^[ \t]*\* ?/g, '')
      comment = comment.replace CoffeeMill.rParam, (matched, type, name, description) ->
        optional = false
        if r = name.match(/^\[(.*)\]$/)
          optional = true
          name = r[1]
        r = name.split('=')
        params.push
          types       : type.split('|')
          optional    : optional
          name        : r[0]
          defaultValue: r[1]
          description : description
        ''
      comment = comment.replace CoffeeMill.rReturn, (matched, type, description) ->
        returns.push
          types      : type.split('|')
          description: description
        ''
      continue if CoffeeMill.rCompletelyBlank.test comment
      r2 = name.match /(\S+)\s*[:=]/
      name = r2[1] if r2? [ 1 ]?
      properties.push
        name   : name
        comment: comment
        params : params
        returns: returns

    switch @makefile.jsdoc.engine
      when 'ejs'
        generateDoc = ejs.compile fs.readFileSync(@makefile.jsdoc.template, 'utf8'),
          compileDebug: true
        doc = generateDoc(
          title     : rawFilename
          properties: properties
        )
          .replace(CoffeeMill.rLineEndSpace, '')
          .replace(CoffeeMill.rBreak, '\n\n')
        fs.writeFileSync @makefile.jsdoc.filename, doc, 'utf8'
      when 'jade'
        generateDoc = jade.compile fs.readFileSync(@makefile.jsdoc.template, 'utf8'),
          compileDebug: true
        doc = generateDoc(
          title     : rawFilename
          properties: properties
        )
          .replace(CoffeeMill.rLineEndSpace, '')
          .replace(CoffeeMill.rBreak, '\n\n')
        fs.writeFileSync @makefile.jsdoc.filename, doc, 'utf8'

  concatFiles: (files) ->
    codes = []
    for file in files
      codes.push fs.readFileSync file, 'utf8'
    codes.join '\n\n'

  coffee: (code, options) ->
    try
      coffee.compile code, options
    catch err
      sys.puts "Compile Error: #{err.toString()}".red


exports.run = ->
  new CoffeeMill process.cwd()
