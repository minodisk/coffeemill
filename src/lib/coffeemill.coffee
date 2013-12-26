util = require 'util'
path = require 'path'
fs = require 'fs'
{ spawn } = require 'child_process'
coffee = require 'coffee-script'
{ Deferred } = require 'jsdeferred'
uglify = require 'uglify-js'
colors = require 'colors'
dateformat = require 'dateformat'
commander = require 'commander'

pkg = JSON.parse fs.readFileSync path.join __dirname, '..', 'package.json'


class CoffeeMill

  EXT_NAMES = [ '.coffee' ]

  @rTagVersion     : /^v?([0-9\.]+)$/
  @rDocComment     : /\/\*\*([\s\S]+?)\*\/\s*(.*)/g
  @rParam          : /@param\s+{?(\S+?)}?\s+(\S+)\s+(.*)/g
  @rReturn         : /@return\s+{?(\S+?)}?\s+(.*)/g
  @rCompletelyBlank: /^\s*$/
  @rLineEndSpace   : /[ \t]+$/g
  @rBreak          : /[\r\n]{3,}/g

  constructor: (@options) ->

  changed: =>
    clearTimeout @timeoutId
    @timeoutId = setTimeout =>
      @run()
    , 500

  run: ->
    # Clear entire screen
    # Move cursor to screen location 0,0
#    if @options.watch
#      process.stdout.write '\u001B[2J\u001B[0;0f'

    # Output current time
    util.puts "CoffeeMill v#{pkg.version}".bold + ' @' + dateformat('HH:MM:ss')

    unless @options.js or @options.uglify or @options.coffee or @options.map
      util.puts 'no output: please specify --js, --uglify, --coffee, or --map'.yellow

    @scanInput()
    @compile()

  scanInput: ->
    if @watchers?
      for watcher in @watchers
        watcher.close()
    @watchers = []

    @hasError = false
    @files = @findFiles @options.input, if @options.watch then @changed else null
#    fs.watch @makefile.jsdoc.template, @changed if @makefile.jsdoc?.template?

  findFiles: (dirs, change, basedir, files = []) ->
    isBasedir = basedir?
    for dir in dirs
      if isBasedir
        dirPath = dir
      else
        dirPath = basedir = dir

      stats = fs.statSync dirPath
      if stats.isFile()
        # when extname is relevant, push filepath into result
        filePath = dirPath
        if EXT_NAMES.indexOf(path.extname filePath) isnt -1
          # parse package name
          packages = path.relative(basedir, filePath).split path.sep
          packages.pop()
          filename = path.basename filePath
          extname = path.extname filePath
          name = path.basename filePath, extname
          className = extendsClassName = null

          # read code
          code = fs.readFileSync filePath, 'utf8'

          if extname is '.coffee'
            # pre-compile to find syntax error
            try
              coffee.compile code
            catch err
              @hasError = true
              @reportCompileError filename, code, err

          # parse class name and dependent class name
          r = code.match /class\s+(\S+)(?:\s+extends\s+(\S+))?/m
          if r?
            [ {},
              className,
              extendsClassName ] = r
          namespaces = packages.concat [name]
          namespace = namespaces.join '.'
          if className? and className isnt namespace
            util.error "class name isn't '#{namespace}' (#{filePath})".yellow

          # stock file object
          files.push
            filePath        : filePath
            extname         : extname
            packages        : packages
            name            : name
            namespaces      : namespaces
            namespace       : namespace
            className       : className
            extendsClassName: extendsClassName
            code            : code

      else if stats.isDirectory()
        # watch dir
        if change?
          @watchers.push fs.watch dirPath, change
        # recursively
        childs = fs.readdirSync dirPath
        for file, i in childs
          childs[i] = path.join dirPath, file
        @findFiles childs, change, basedir, files

    files

  compile: ->
    return if @hasError

    cs = ''
    csName = ''

    Deferred
      .next =>
        switch @options.ver
          when 'none'
            ''
          when 'gitTag'
            @gitTag()
          else
            @options.ver
      .error (err) =>
        ''
      .next (version) =>
        if version isnt ''
          util.puts 'version: ' + version
          postfix = "-#{version}"
        else
          postfix = ''


        # resolve dependency
        normalFiles = []
        classFiles = []
        classNames = []
        resolvedFiles = []

        # search internal class name
        for file in @files
          if file.className?
            classFiles.push file
            classNames.push file.className
          else
            normalFiles.push file

        # add no dependent and external dependent class
        i = classFiles.length
        while i--
          {extendsClassName} = classFiles[i]
          if not extendsClassName? or classNames.indexOf(extendsClassName) is -1
            resolvedFiles.unshift classFiles.splice(i, 1)[0]

        # add internal dependent class
        while i = classFiles.length
          while i--
            {extendsClassName} = classFiles[i]
            for {className}, j in resolvedFiles
              if className is extendsClassName
                resolvedFiles.splice j + 1, 0, classFiles.splice(i, 1)[0]
                break

        @files = normalFiles.concat resolvedFiles


        codes = []
        exports = {}
        for { code, name, className, packages, namespace } in @files
          codes.push code

          # add package namespace to export list
          exp = exports
          for packageNamespace in packages
            unless exp[packageNamespace]?
              exp[packageNamespace] = {}
            exp = exp[packageNamespace]

        # generate export code
        cs = []
        .concat(
          do -> "#{name} = #{JSON.stringify obj}" for name, obj of exports
          [
            """
            ___exports = #{JSON.stringify exports}
            """
          ],
          do ->
            codes.map (code) ->
              code.replace /class\s+(\S+)/g, '___exports.$1 = class $1'
          ,
          [
            """
            do ->
              ___extend = (child, parent) ->
                for key, val of parent
                  continue unless Object::hasOwnProperty.call parent, key
                  if Object::toString.call(val) is '[object Object]'
                    child[key] = {}
                    ___extend child[key], val
                  else
                    child[key] = val
              if window?
                ___extend window, ___exports
              if module?.exports?
                ___extend module.exports, ___exports
            """
          ]
        )
        .join('\n\n')
        csName = "#{@options.name}#{postfix}.coffee"


        outputs = []

        if @options.coffee
          outputs.push
            type    : 'coffee'
            filename: csName
            data    : cs

        if @options.map
          { js, v3SourceMap: map } = coffee.compile cs,
            sourceMap    : true
            generatedFile: "#{@options.name}#{postfix}.js"
            sourceRoot   : ''
            sourceFiles  : [ "#{@options.name}#{postfix}.coffee" ]
        else
          js = coffee.compile cs

        if @options.js
          if map?
            js += "\n/*\n//@ sourceMappingURL=#{@options.name}#{postfix}.map\n*/"
          outputs.push
            type    : 'js'
            filename: "#{@options.name}#{postfix}.js"
            data    : js

        if map?
          outputs.push
            type    : 'source map'
            filename: "#{@options.name}#{postfix}.map"
            data    : map

        if @options.uglify
          { code: uglified } = uglify.minify js,
            fromString: true
          if postfix is ''
            ext = '-min.js'
          else
            ext = '.min.js'
          outputs.push
            type    : 'uglify'
            filename: "#{@options.name}#{postfix}#{ext}"
            data    : uglified

        len = 0
        for {type} in outputs
          len = Math.max len, type.length
        for {type}, i in outputs
          while type.length < len
            type += ' '
          outputs[i].type = type

        cwd = process.cwd()
        counter = 0
        for outputDir in @options.output
          outputDir = path.resolve cwd, outputDir
          # Make output directory
          fs.mkdirSync outputDir unless fs.existsSync outputDir

          for {type, filename, data} in outputs
            outputPath = path.resolve cwd, path.join outputDir, filename
            fs.writeFileSync outputPath, data, 'utf8'
            util.puts "#{type}: ".green + path.relative '.', outputPath
            counter++

        util.puts "✔ #{counter} file#{if counter > 1 then 's' else ''} complete.".cyan
        unless @options.watch
          process.exit 0

      .error (err) =>
        if err.location?
          @reportCompileError csName, cs, err
        else
          util.error "#{err.stack}".red

  reportCompileError: (csName, cs, err) ->
    if err.location?
      {location:{ first_line, first_column, last_line, last_column }} = err
      lines = cs.split /\r?\n/
      code = lines.splice first_line, 1

      unless first_line is last_line
        last_line = first_line
        last_column = code.length - 1
      if last_column <= first_column
        last_column = first_column


      # formatting
      mark = ''
      while mark.length < first_column
        mark += ' '
      while mark.length <= last_column
        mark += '^'
      lineNumber = '' + first_line
      nextLineNumber = ''
      while nextLineNumber.length < lineNumber.length
        nextLineNumber += ' '
      util.error """
        #{csName}:#{first_line}:#{first_column}
        #{err.toString().red}
        #{(lineNumber + '.').grey}#{code}
        #{(nextLineNumber + '.').grey}#{mark.red}
        """
    else
      util.error """
        CoffeeScript Compiler
        #{err.toString().red}
        """

    unless @options.watch
      process.exit 1


  indent: (code) ->
    lines = code.split /\r?\n/g
    for line, i in lines
      lines[i] = '  ' + line
    lines.join '\n'

  gitTag: ->
    d = new Deferred()
    gitTag = spawn 'git', [ 'tag' ]
    out = ''
    gitTag.stdout.setEncoding 'utf8'
    gitTag.stdout.on 'data', (data) ->
      out += data
    err = ''
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
        d.call versions.join '.'
        return
      d.fail 'no tag as version'
    d


module.exports =
  CoffeeMill: CoffeeMill

  run: ->

    list = (val) -> val.split ','

    commander
    .version(pkg.version)
    .usage('[options]')
    .option('-i, --input <dirnames>', 'output directory (defualt is \'src\')', list, [ 'src' ])
    .option('-o, --output <dirnames>', 'output directory (defualt is \'lib\')', list, [ 'lib' ])
    .option('-n, --name [basename]', 'output directory (defualt is \'main\')', 'main')
    .option('-v, --ver <version>', 'file version: supports version string, \'gitTag\' or \'none\' (default is \'none\')', 'none')
    .option('-j, --js', 'write JavaScript file (.js)')
    .option('-u, --uglify', 'write uglified JavaScript file (.min.js)')
    .option('-c, --coffee', 'write CoffeeScript file (.coffee)')
    .option('-m, --map', 'write source maps file JavaScript to CoffeeScript (.map)')
    .option('-w, --watch', 'watch the change of input directory recursively')
    .parse(process.argv)

    new CoffeeMill(commander).run()

