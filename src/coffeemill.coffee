fs = require 'fs'
path = require 'path'
{spawn} = require 'child_process'
coffee = require 'coffee-script'
{parser, uglify} = require 'uglify-js'
{Relay} = require 'relay'
colors = require 'colors'

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
  package = JSON.parse fs.readFileSync path.join(__dirname, '../package.json'), 'utf8'
  package.version

exports.help = ->
  """
  Usage   : coffeemill [-o output_dir] [-t test_dir] [src_dir]
  Options : -o, --output [DIR] set the output directory for compiled JavaScript (lib)
            -t, --test [DIR]   set the test directory (test)
            -c, --compress     compress the compiled JavaScript
            -b, --bare         compile without a top-level function wrapper
            -j, --join [FILE]  concatenate the source CoffeeScript before compiling
            -h, --help         display this help message
            -v, --version      display the version number
  Argument: source directory (src)
  """

exports.grind = (input = 'src', output = 'lib', test = null, join = null, bare = false, compress = false, silent = false, callback = null)->
  if silent then stdout = ->
  opts =
    requested: false
    input    : input
    output   : output
    test     : test
    join     : join
    bare     : bare
    compress : compress
    silent   : silent
    callback : callback
  info """
    input directory : #{String(opts.input).bold}
    output directory: #{String(opts.output).bold}
    test directory  : #{String(opts.test).bold}
    join files to   : #{String(opts.join).bold}
    bare            : #{String(opts.bare).bold}
    compress        : #{String(opts.compress).bold}
    silent          : #{String(opts.silent).bold}
    """
  Relay.serial(
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
    Relay.serial(
      Relay.func((dir)->
        @local.dir = dir
        fs.stat dir, @next
      )
      Relay.func((err, stats)->
        unless err?
          info "start watching directory: #{String(@local.dir).bold}"
          fs.watch @local.dir, (event, filename)->
            onDirChanged opts
        @next()
      )
    )
  )
  .complete(->
    callback?()
  )
  .start dirs
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

startCompile = (opts)->
  Relay.serial(
    Relay.func(->
      info "start compiling".cyan.bold
      fs.stat opts.output, @next
    )
    Relay.func((err, stats)->
      if err?
        error "'#{opts.output}' does'nt exist"
      else
        fs.readdir opts.input, @next
    )
    Relay.func((err, files)->
      if err?
        error err
      else
        @next files
    )
    Relay.each(
      Relay.serial(
        Relay.func((file)->
          @local.basename = path.basename file, path.extname(file)
          fs.readFile path.join(opts.input, file), 'utf8', @next
        )
        Relay.func((err, code)->
          if err?
            @skip()
          else
            compileOpts =
              bare: opts.bare
            if join?
              compileOpts.join = @join
            if R_ENV.test code
              node = code.replace R_ENV, (matched, $1, $2, offset, source)->
                if $2? then $2 else ''
              node = coffee.compile node, compileOpts
              browser = code.replace R_ENV, (matched, $1, $2, offset, source)->
                if $1? then $1 else ''
              browser = coffee.compile browser, compileOpts
              files = [
                { path: "node/#{@local.basename}.js", code: node }
                { path: "browser/#{@local.basename}.js", code: browser }
              ]
              if opts.compress
                files.push { path: "browser/#{@local.basename}.min.js", code: compress browser }
              @next files
            else
              code = coffee.compile code, compileOpts
              files = [
                { path: "#{@local.basename}.js", code: code }
              ]
              if opts.compress
                files.push { path: "#{@local.basename}.min.js", code: compress code }
              @next files
        )
        Relay.each(
          Relay.serial(
            Relay.func((file)->
              @local.filename = path.join opts.output, file.path
              fs.writeFile @local.filename, file.code, @next
            )
            Relay.func((err)->
              if err?
                error err
                @skip()
              else
                info "write file: #{String(@local.filename).bold}"
                @next()
            )
          )
        )
      )
    )
    Relay.func(->
      info "complete compiling".cyan.bold
      @next()
    )
  )
  .complete(->
    if opts.test?
      test opts
    else
      opts.callback?()
  )
  .start()
  return

compress = (code)->
  uglify.gen_code uglify.ast_squeeze uglify.ast_mangle parser.parse code

test = (opts)->
  Relay.serial(
    Relay.func(->
      fs.stat opts.test, @next
    )
    Relay.func((err, stats)->
      unless err?
        info "start testing".cyan.bold
        nodeunit = spawn 'nodeunit', [opts.test]
        nodeunit.stderr.setEncoding 'utf8'
        nodeunit.stderr.on 'data', (data)->
          error data.replace(/^\s*/, '').replace(/\s*$/, '')
        nodeunit.stdout.setEncoding 'utf8'
        nodeunit.stdout.on 'data', (data)->
          info data.replace(/^\s*/, '').replace(/\s*$/, '')
        nodeunit.on 'exit', (code)->
          info "complete testing".cyan.bold
      @next()
    )
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
