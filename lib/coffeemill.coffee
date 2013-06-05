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
    sys.puts new Date().toString().underline

    list = (val) ->
      val.split ','

    commander
      .version(JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'package.json'))).version)
      .usage('[options]')
      .option('-n, --name <basename>', 'output directory (defualt is \'\')', '')
      .option('-i, --input <dirnames>', 'output directory (defualt is \'src\')', list,
        [ 'src' ])
      .option('-o, --output <dirnames>', 'output directory (defualt is \'lib\')', list,
        [ 'lib' ])
      .option('-u, --uglify', 'minify with uglifyJS (.min.js)')
      .option('-m, --map', 'generate source maps (.map)')
      .option('-w, --watch', 'watch the change of input directory recursively')
      .option('-v, --ver <version>', 'file version: supports version string, \'gitTag\' or \'none\' (default is \'none\')', 'none')
      .option('--jsDoc', 'generate jsDoc')
      .option('--jsDocEngine <engine>', 'jsDoc template engine (default is \'ejs\')', 'ejs')
      .option('--jsDocTemplate <filename>', 'jsDoc template', 'README.ejs')
      .option('--jsDocOutput <filename>', 'jsDoc output', 'README.md')
      .parse(process.argv)

    @scanInput()
    @compile()

  scanInput: ->
    if @watchers?
      for watcher in @watchers
        watcher.close()
    @watchers = []

    @hasError = false
    @files = @findFiles commander.input, if commander.watch then @changed else null
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
            sys.puts "class name isn't '#{namespace}' (#{filePath})".yellow

          # stock file object
          files.push
            filePath   : filePath
            extname    : extname
            packages   : packages
            name       : name
            namespaces : namespaces
            namespace  : namespace
            className  : className
            extendsClassName: extendsClassName
            code       : code

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

  changed: =>
    clearTimeout @timeoutId
    @timeoutId = setTimeout =>
      @scanInput()
      @compile()
    , 100

  compile: ->
    return if @hasError

    cs = ''
    csName = ''

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


        # resolve dependency
        dependency = []
        classNames = []

        # search internal class name
        for {className} in @files
          classNames.push className

        # add no dependent and external dependent class
        i = @files.length
        while i--
          {extendsClassName} = @files[i]
          if not extendsClassName? or classNames.indexOf(extendsClassName) is -1
            dependency.unshift @files.splice(i, 1)[0]

        # add internal dependent class
        while i = @files.length
          while i--
            {extendsClassName} = @files[i]
            for {className}, j in dependency
              if className is extendsClassName
                dependency.splice j + 1, 0, @files.splice(i, 1)[0]
                break

        @files = dependency


        codes = []
        exports = {}
        for {code, name, className, packages, namespace} in @files
          codes.push code

          # add package namespace to export list
          exp = exports
          for pkg in packages
            exp[pkg] = {} unless exp[pkg]?
            exp = exp[pkg]

        # generate export code
        for k, v of exports
          codes.unshift """
            #{k} = #{JSON.stringify v, null, 2}
            if window? then window.#{k} = #{k}
            if module? then module.exports = #{k}
            """
        cs = codes.join '\n\n'
        csName = "#{commander.name}#{postfix}.coffee"


        outputs = []

        outputs.push
          type    : '.coffee'
          filename: csName
          data    : cs

        { js: js, v3SourceMap: map } = coffee.compile cs,
          sourceMap    : true
          generatedFile: "#{commander.name}#{postfix}.js"
          sourceRoot   : ''
          sourceFiles  : [ "#{commander.name}#{postfix}.coffee" ]
        if commander.map
          js += "\n/*\n//@ sourceMappingURL=#{commander.name}#{postfix}.map\n*/"
        outputs.push
          type    : '.js    '
          filename: "#{commander.name}#{postfix}.js"
          data    : js

        if commander.map
          outputs.push
            type    : '.map   '
            filename: "#{commander.name}#{postfix}.map"
            data    : map

        if commander.uglify
          { uglified } = uglify.minify js, { fromString: true }
          outputs.push
            type    : '.min.js'
            filename: "#{commander.name}#{postfix}.min.js"
            data    : uglified


        for outputDir in commander.output
          outputDir = path.resolve @cwd, outputDir
          # Make output directory
          fs.mkdirSync outputDir unless fs.existsSync outputDir

          for {type, filename, data} in outputs
            outputPath = path.resolve @cwd, path.join outputDir, filename
            fs.writeFileSync outputPath, data, 'utf8'
            sys.puts "#{type}: ".cyan + outputPath

#        if commander.jsDoc
#          @jsDoc cs

        sys.puts 'complete!!'.green

      .error (err) =>
        if err.location?
          @reportCompileError csName, cs, err
        else
          sys.error "#{err.stack}".red

  reportCompileError: (csName, cs, err) ->
    {location:{ first_line, first_column, last_line, last_column }} = err
    lines = cs.split '\n'
    code = lines.splice(first_line, last_line - first_line + 1).join('\n')
    before = code.substring 0, first_column
    error = code.substring first_column, last_column + 1
    after = code.substring last_column + 1

    sys.error """#{"#{csName}:#{first_line}:#{first_column} #{err.toString()}".red}
      #{before}#{error.red.inverse}#{after}
      """

  jsDoc: (code) ->
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


exports.run = ->
  new CoffeeMill process.cwd()
