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

  @rTagVersion     : /^v?([0-9\.]+)$/
  @rDocComment     : /\/\*\*([\s\S]+?)\*\/\s*(.*)/g
  @rParam          : /@param\s+{?(\S+?)}?\s+(\S+)\s+(.*)/g
  @rReturn         : /@return\s+{?(\S+?)}?\s+(.*)/g
  @rCompletelyBlank: /^\s*$/
  @rLineEndSpace   : /[ \t]+$/g
  @rBreak          : /[\r\n]{3,}/g

  constructor: (@cwd) ->
    @makefilePath = path.join @cwd, 'makefile.coffee'

    commander
      .version('0.0.1')
      .usage('[options]')
      .option('-w, --watch', 'watch the change of src directory')
      .option('-v, --ver <version>', 'specify version')
      .option('-c, --copy <path>', 'copy compiled file')
      .parse(process.argv)

    @readMakefile()
    @startWatch()
    @compile()

  readMakefile: ->
    @makefile = require @makefilePath

  startWatch: ->
    return unless commander.watch
    fs.watch @makefilePath, @changed
    fs.watch @makefile.src.dir, @changed
    fs.watch @makefile.jsdoc.template, @changed if @makefile.jsdoc?.template?

  changed: =>
    clearTimeout @_id
    @_id = setTimeout =>
      @compile()
    , 100

  compile: ->
    sys.puts new Date().toString().underline

    Deferred
      .next =>
        if commander.ver?
          commander.ver
        else unless @makefile.compiler.useGitTag
          ''
        else
          @gitTag()
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
        if @makefile.src.files?
          filePathes = @makefile.src.files
          for file, i in files
            files[i] = path.join @cwd, @makefile.src.dir, file
        else
          filePathes = @findFiles path.join @cwd, @makefile.src.dir


        # 1. read code
        # 2. parse package name, class name and parent class name
        files = []
        for filePath in filePathes
          code = fs.readFileSync filePath, 'utf8'
          r = code.match /^\s*#package\s+([\w\.]+)/
          if r?
            [ {},
            packageName ] = r
          r = code.match /class\s+(\w+)(?:\s+extends\s+(\w+))?/m
          if r?
            [ {},
              className,
              parentClassName ] = r
          files.push
            packageName    : packageName or ''
            className      : className or ''
            parentClassName: parentClassName or ''
            filePath       : filePath
            code           : code

        # sort on dependency
        files.sort (a, b) ->
          if a.parentClassName is ''
            -1
          else if b.parentClassName is ''
            1
          else if b.parentClassName is a.className
            -1
          else if a.parentClassName is b.className
            1
          else
            0

        # 1. find package
        # 2. concat codes
        # 3. add exports
        codes = []
        exports = {}
        for file in files
          console.log file.parentClassName, '->', file.className
          codes.push file.code
          exp = exports
          if file.packageName isnt ''
            ps = file.packageName.split '.'
            for p in ps
              unless exp[p]?
                exp[p] = {}
              exp = exp[p]
          exp[file.className] = file.className
        codes.push 'window[k] = v for k, v of ' + JSON.stringify(exports, null, 2).replace(/(:\s+)"(\w+)"/g, '$1$2')
        code = codes.join '\n\n'


        filename = "#{@makefile.dst.file}#{postfix}.coffee"
        output = path.join @cwd, @makefile.dst.dir, filename
        fs.writeFileSync output, code, 'utf8'
        sys.puts 'concat    : '.cyan + output
        @copy code, filename

        { js: code, v3SourceMap } = @coffee code
        if @makefile.compiler.sourceMap
          code += "\n/*\n//@ sourceMappingURL=#{@makefile.dst.file}#{postfix}.map\n*/"
        filename = "#{@makefile.dst.file}#{postfix}.js"
        output = path.join @cwd, @makefile.dst.dir, filename
        fs.writeFileSync output, code, 'utf8'
        sys.puts 'compile   : '.cyan + output
        @copy code, filename

        if @makefile.compiler.sourceMap
          filename = "#{@makefile.dst.file}#{postfix}.map"
          output = path.join @cwd, @makefile.dst.dir, filename
          fs.writeFileSync output, v3SourceMap, 'utf8'
          sys.puts 'source map: '.cyan + output
          @copy code, filename

        if @makefile.compiler.minify
          { code } = uglify.minify code, { fromString: true }
          filename = "#{@makefile.dst.file}#{postfix}.min.js"
          output = path.join @cwd, @makefile.dst.dir, filename
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
        continue unless r?[1]?
        versions = r[1].split '.'
        minor = parseInt versions[versions.length - 1], 10
        versions[versions.length - 1] = minor + 1
        return d.call versions.join '.'
      d.fail 'no tag as version'
    d

  findFiles: (dir, files = []) ->
    for file in fs.readdirSync dir
      file = path.join dir, file
      stats = fs.statSync file
      if stats.isFile()
        files.push file
      else if stats.isDirectory()
        @findFiles file, files
    files


  jsdoc: (wholeCode) ->
    if @makefile.jsdoc.src.files?
      files = @makefile.jsdoc.src.files
      for file, i in files
        files[i] = path.join @cwd, @makefile.jsdoc.src.dir, file
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

  coffee: (code) ->
    try
      coffee.compile code, { sourceMap: true }
    catch err
      sys.puts "Compile Error: #{err.toString()}".red


exports.run = ->
  new CoffeeMill process.cwd()
