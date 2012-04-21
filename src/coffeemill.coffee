fs = require 'fs'
path = require 'path'
{spawn} = require 'child_process'
coffee = require 'coffee-script'
{parser, uglify} = require 'uglify-js'
{Relay} = require 'relay'
colors = require 'colors'
jade = require 'jade'
{Markdown} = require 'node-markdown'
sorter = require 'sorter'

R_ENV = /#if\s+BROWSER([\s\S]*?)(#else[\s\S]*?)?#endif/g

info = (log)->
  stdout 'info', 'cyan', log

error = (log)->
  stdout 'error', 'red', log

stdout = (prefix, prefixColor, log)->
  indent = ''
  len = 10 + prefix.length
  while len--
    indent += ' '
  log = log.toString?().replace(/\n+/g, "\n#{indent}")
  console.log "#{prefix[prefixColor].inverse} #{timeStamp().grey} #{log}"

exports.version = ->
  pkg = JSON.parse fs.readFileSync path.join(__dirname, '../package.json'), 'utf8'
  pkg.version

exports.grind = (opts, callback)->
  unless opts.input? then opts.input = 'src'
  unless opts.output? then opts.output = 'lib'
  path.normalize opts.input
  path.normalize opts.output
  if opts.test? then path.normalize opts.test
  if opts.silent then stdout = ->
  opts.requested = false
  opts.callback = callback
  info """
    input dir       : #{String(opts.input).bold}
    output dir      : #{String(opts.output).bold}
    join files to   : #{String(opts.join).bold}
    minify          : #{String(opts.minify).bold}
    bare            : #{String(opts.bare).bold}
    docs output dir : #{String(opts.docs).bold}
    docs template   : #{String(opts.template).bold}
    test directory  : #{String(opts.test).bold}
    run             : #{String(opts.run).bold}
    silent          : #{String(opts.silent).bold}
    """
  Relay.serial(
    Relay.func(->
      if opts.template?
        fs.readFile opts.template, 'utf8', @next
      else
        @next()
    )
    Relay.func((err, template)->
      if err?
        throw err
        @skip()
      else
        opts.compiler = jade.compile template, { pretty: true }
      @next()
    )
    Relay.func(->
      startWatch opts, @next
    )
    Relay.func(->
      startCompile opts
      @next()
    )
  ).start()

startWatch = (opts, callback)->
  dirs = [opts.input]
  if opts.test then dirs.push opts.test
  Relay.each(
    Relay.func((dir)->
      watch dir, opts, @next
    )
  )
  .complete(callback)
  .start dirs
  return

watch = (dir, opts, callback)->
  Relay.serial(
    Relay.func(->
      fs.stat dir, @next
    )
    Relay.func((err, stats)->
      if err?
        @skip()
      else
        unless stats.isDirectory()
          @skip()
        else
          info "start watching directory: #{String(dir).bold}"
          fs.watch dir, (event, filename)->
            onDirChanged opts
          fs.readdir dir, @next
    )
    Relay.func((err, files)->
      if err?
        @skip()
      else
        @next files
    )
    Relay.each(
      Relay.func((file)->
        watch path.join(dir, file), opts, @next
      )
    )
  )
  .complete(callback)
  .start()
  return

onDirChanged = (opts)->
  unless opts.requested
    info "detect changed"
    opts.requested = true
    setTimeout (->
      opts.requested = false
      startCompile opts
    ), 1000
  return

getFiles = (dir, callback)->
  Relay.serial(
    Relay.func(->
      @global.files = []
      fs.readdir dir, @next
    )
    Relay.func((err, files)->
      if err?
        @skip()
      else
        @next files
    )
    # Run each serially not to break file order.
    Relay.each(
      Relay.serial(
        Relay.func((file)->
          @local.file = path.join dir, file
          fs.stat @local.file, @next
        )
        Relay.func((err, stats)->
          if err?
            @skip()
          else if stats.isDirectory()
            getFiles @local.file, @next
          else if stats.isFile()
            @next [@local.file]
          else
            @skip()
        )
        Relay.func((files)->
          @global.files = @global.files.concat files
          @next()
        )
      ), true
    )
  )
  .complete(->
    callback @global.files
  )
  .start()

write = (filename, code, callback)->
  Relay.serial(
    Relay.func(->
      dirs = filename.split '/'
      @global.filename = ''
      @next dirs
    )
    Relay.each(
      Relay.serial(
        Relay.func((dir, i, dirs)->
          filename = @global.filename = path.join @global.filename, dir
          if i isnt dirs.length - 1
            fs.mkdir filename, @next
          else
            fs.writeFile filename, code, @next
        )
        Relay.func((err)->
          unless err?
            info "write file: #{String(@global.filename).bold}"
          @next()
        )
      )
    )
  )
  .complete(->
    callback?()
  )
  .start()

getFilepath = (filename, dir)->
  basename = path.basename filename, path.extname(filename)
  tmp = path.join filename, '..', basename
  input = dir.split '/'
  tmp   = tmp.split '/'
  p = []
  i = tmp.length
  while i-- and tmp[i] isnt input[i]
    p.unshift tmp[i]
  p.join '/'

getComment = (value)->
  doc =
    texts: []
  for line in value.split /\n|\r\n?/
    if ($ = line.match /^@(\w+)\s+(.*)?/) and (key = $[1])
      unless doc[key] then doc[key] = []
      switch key
        when 'param', 'property'
          if $ = $[2].match /^(\w+)\s+(\w+)\s+(.*)/
            doc[key].push(
              name: $[1]
              type: $[2]
              text: $[3]
            )
        when 'returns'
          if $ = $[2].match /^(\w+)\s+(.*)/
            doc[key] =
              type: $[1]
              text: $[2]
        when 'type'
          if $ = $[2].match /^(\w+)/
            doc[key].push(
              type: $[1]
            )
    else if line isnt ''
      doc.texts.push line
  doc.text = Markdown doc.texts.join '\n'
  doc

generateDoc = (code, opts, filepath, callback)->
  if path.basename(filepath).charAt(0) is '_'
    callback?()
    return

  head = {}
  docs = []

  indent = 0
  param = false
  idTokens = []
  comment = null

  tokens = coffee.tokens code
  for token, i in tokens
    [type, value] = token
    token =
      type : type
      value: value

    switch type
      when 'INDENT'
        indent++
      when 'OUTDENT'
        indent--
      when 'PARAM_START'
        param = true
      when 'PARAM_END'
        param = false

    switch indent
      when 0
        switch type
          when 'HERECOMMENT'
            if value.charAt(0) is '*'
              for key, value of getComment value.substr 1
                head[key] = value

          when 'IDENTIFIER'
            idTokens.push token
            switch prevToken?.type
              when 'CLASS'
                head.class = value
              when 'EXTENDS'
                head.extends = value

      when 1
        switch type
          when 'HERECOMMENT'
            if value.charAt(0) is '*'
              comment = getComment value.substr 1

          when 'IDENTIFIER'
            unless param
              doc =
                static : prevToken.type is '@'
                type   : 'property'
                name   : value
                private: value.charAt(0) is '_'
                returns:
                  type: 'void'
              for key, value of comment
                doc[key] = value
              docs.push doc
              comment = null
          when '->', '=>'
            doc.type = 'function'

    if i is tokens.length - 1 and not head.class?
      head.class = idTokens[idTokens.length - 1].value
      for doc in docs
        doc.static = true

    prevToken = token

  data =
    head : head
    static:
      properties: []
      methods   : []
    constructor: null
    member:
      properties: []
      methods   : []
    toParamString: (param)->
      if param?
        params = []
        for {name, type} in param
          params.push "#{name}:#{type}"
        params.join ', '
      else
        ''

  for doc in docs
    if doc.name is 'constructor'
      doc.name = head.class
      data.constructor = doc
    else
      obj = if doc.static then data.static else data.member
      if doc.type is 'function'
        obj.methods.push doc
      else
        obj.properties.push doc

  sorter.dictSort data.static.properties, 'name'
  sorter.dictSort data.static.methods, 'name'
  sorter.dictSort data.member.properties, 'name'
  sorter.dictSort data.member.methods, 'name'

  Relay.serial(
    Relay.func(->
      @local.filename = path.join(opts.docs, "#{filepath}.html")
      write @local.filename, opts.compiler(data), @next
    )
    Relay.func(->
      @next()
    )
  )
  .complete(->
    callback?()
  )
  .start()

generateIndexDoc = (filepaths, opts, callback)->
  packages = {}
  sorter.dictSort filepaths
  for filepath in filepaths
    unless path.basename(filepath).charAt(0) is '_'
      package = filepath.split '/'
      name = package.pop()
      package = package.join('.')

      unless packages[package]?
        packages[package] = []
      packages[package].push
        name: name
        url : "#{filepath}.html"

  console.log packages
  html = opts.compiler(
    packages: packages
  )
  write path.join(opts.docs, 'index.html'), html, callback

compile = (code, opts, filepath, callback)->
  Relay.serial(
    Relay.func(->
      compileOpts = {}
      if opts.bare then compileOpts.bare = opts.bare
      if R_ENV.test code
        node = code.replace R_ENV, (matched, $1, $2, offset, source)->
          if $2? then $2 else ''
        node = coffee.compile node, compileOpts
        browser = code.replace R_ENV, (matched, $1, $2, offset, source)->
          if $1? then $1 else ''
        browser = coffee.compile browser, compileOpts
        details = [
          { path: "node/#{filepath}.js", code: beautify node }
          { path: "browser/#{filepath}.js", code: beautify browser }
        ]
        if opts.minify
          details.push { path: "browser/#{filepath}.min.js", code: minify browser }
        @next details
      else
        code = coffee.compile code, compileOpts
        details = [
          { path: "#{filepath}.js", code: beautify code }
        ]
        if opts.minify
          details.push { path: "#{filepath}.min.js", code: minify code }
        @next details
    )
    Relay.each(
      Relay.serial(
        Relay.func((detail)->
          @local.filename = path.join opts.output, detail.path
          write @local.filename, detail.code, @next
        )
        Relay.func(->
          @next()
        )
      )
    )
  )
  .complete(callback)
  .start()

startCompile = (opts)->
  Relay.serial(
    Relay.func(->
      info "start compiling".cyan.bold
      @global.filepaths = []
      fs.stat opts.output, @next
    )
    Relay.func((err, stats)->
      if err?
        error "'#{opts.output}' does'nt exist"
      else
        getFiles opts.input, @next
    )
    do ->
      if opts.join?
        Relay.serial(
          Relay.func((files)->
            @global.details = []
            @next files
          )
          Relay.each(
            Relay.serial(
              Relay.func((file)->
                @local.detail =
                  file: file
                @global.details.push @local.detail
                fs.readFile @local.detail.file, 'utf8', @next
              )
              Relay.func((err, code)->
                if err?
                  @skip()
                else
                  @local.detail.code = code
                  tokens = coffee.tokens @local.detail.code
                  for token, i in tokens
                    switch token[0]
                      when 'CLASS'
                        unless @local.detail.class?
                          @local.detail.class = tokens[i + 1][1]
                      when 'EXTENDS'
                        unless @local.detail.depends?
                          @local.detail.depends = tokens[i + 1][1]

                  if opts.compiler?
                    filepath = getFilepath @local.detail.file, opts.input
                    generateDoc code, opts, filepath
                    @global.filepaths.push filepath

                  @next()
              )
            ), true
          )
          Relay.func(->
            # sort on dependency
            details = @global.details

            for detail in details
              internal = false
              for d in details
                if d isnt detail
                  if detail.depends is d.class
                    internal = true
                    break
              unless internal
                detail.depends = null

            sorted = []
            counter = 0
            while i = details.length
              if counter++ is 100
                throw new Error "Can't resolve dependency."
              tmp = []
              while i--
                detail = details[i]

                displace = false
                unless detail.depends?
                  displace = true
                else
                  for d in sorted
                    if detail.depends is d.class
                      displace = true
                      break

                if displace
                  details.splice i, 1
                  tmp.push detail

              tmp.reverse()
              sorted = sorted.concat tmp
            details = sorted

            code = ''
            if opts.bare?
              for detail in details
                code += detail.code
            else
              for detail in details
                code += "#{detail.code}\n"

            compile code, opts, opts.join, @next
          )
        )
      else
        Relay.each(
          Relay.serial(
            Relay.func((file)->
              @local.path = getFilepath(file, opts.input)
              fs.readFile file, 'utf8', @next
            )
            Relay.func((err, code)->
              if err?
                @skip()
              else
                compile code, opts, @local.path, @next
                if opts.compiler?
                  generateDoc code, opts, @local.path
                  @global.filepaths.push @local.path
            )
          )
        )
    Relay.func(->
      generateIndexDoc @global.filepaths, opts, @next
    )
    Relay.func(->
      info "complete compiling".cyan.bold
      @next()
    )
  )
  .complete(->
    if opts.test?
      test opts
    else if opts.run?
      runCommand opts
    else
      opts.callback?()
  )
  .start()
  return

minify = (code)->
  uglify.gen_code uglify.ast_squeeze(uglify.ast_mangle(parser.parse(code)))

beautify = (code)->
  uglify.gen_code parser.parse(code),
    beautify: true
    indent_start: 0
    indent_level: 2

test = (opts)->
  Relay.func(->
    info "start testing".cyan.bold
    nodeunit = spawn 'nodeunit', [opts.test]
    nodeunit.stderr.setEncoding 'utf8'
    nodeunit.stderr.on 'data', (data)->
      error data.replace(/^\s*/, '').replace(/\s*$/, '')
    nodeunit.stdout.setEncoding 'utf8'
    nodeunit.stdout.on 'data', (data)->
      info data.replace(/^\s*/, '').replace(/\s*$/, '')
    nodeunit.on 'exit', (code)=>
      info "complete testing".cyan.bold
      @next()
  )
  .complete(->
    if opts.run?
      runCommand opts
    else
      opts.callback?()
  )
  .start()
  return

runCommand = (opts)->
  Relay.func(->
    info "#{'running command'.cyan.bold}: #{opts.run.bold}"
    commands = opts.run.split /\s+/
    nodeunit = spawn commands.shift(), commands
    nodeunit.stderr.setEncoding 'utf8'
    nodeunit.stderr.on 'data', (data)->
      error data.replace(/^\s*/, '').replace(/\s*$/, '')
    nodeunit.stdout.setEncoding 'utf8'
    nodeunit.stdout.on 'data', (data)->
      info data.replace(/^\s*/, '').replace(/\s*$/, '')
    nodeunit.on 'exit', (code)=>
      info "complete running command".cyan.bold
      @next()
  )
  .complete(->
    opts.callback?()
  )
  .start()
  return

timeStamp = ->
  date = new Date()
  "#{padLeft date.getHours()}:#{padLeft date.getMinutes()}:#{padLeft date.getSeconds()}"

padLeft = (num, length = 2, pad = '0')->
  str = num.toString 10
  while str.length < length
    str = pad + str
  str
