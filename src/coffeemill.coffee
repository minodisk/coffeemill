fs = require 'fs'
path = require 'path'
{spawn} = require 'child_process'
coffee = require 'coffee-script'
{parser, uglify} = require 'uglify-js'
{Relay} = require 'relay'

exports.CoffeeMill = class CoffeeMill

  @R_ENV: /#if\s+BROWSER([\s\S]*?)(#else[\s\S]*?)?#endif/g

  @version: ->
    package = JSON.parse fs.readFileSync path.join(__dirname, '../package.json'), 'utf8'
    package.version

  @help: ->
    """
    Usage    : coffeemill [-o output_dir] [-t test_dir] [src_dir]
    Options  : -v, --version  print coffeemill's version
               -h, --help     print coffeemill's help
               -o, --output   output directory (default is lib)
               -t, --test     test directory (default is test)
               -c, --compress make compressed JavaScript
    Argument : watching directory (default is src)
    """

  constructor: ->
    @requested = false
  
  grind: (@srcDir = 'src', @dstDir = 'lib', @testDir = 'test', @isComplress = false)->
    @startWatch()
    @startCompile()
  
  startWatch: =>
    self = @
    Relay.each(
      Relay.serial(
        Relay.func((dir)->
          @local.dir = dir
          fs.stat dir, @next
        )
        Relay.func((err, stats)->
          unless err?
            console.log "#{self.timeStamp()} Start watching directory: #{@local.dir}"
            fs.watch @local.dir, self.onDirChanged
          @next()
        )
      )
    ).start [self.srcDir, self.testDir]

  onDirChanged: (event, filename)=>
    self = @
    unless self.requested
      console.log "#{self.timeStamp()} Detect changed"
      self.requested = true
      setTimeout (->
        self.requested = false
        self.startCompile()
      ), 1000
  
  timeStamp: ->
    date = new Date()
    "#{@padLeft date.getHours()}:#{@padLeft date.getMinutes()}:#{@padLeft date.getSeconds()}"
  
  padLeft: (num, length = 2, pad = '0')->
    str = num.toString 10
    while str.length < length
      str = pad + str
    str

  startCompile: =>
    self = @
    Relay.serial(
      Relay.func(->
        console.log "#{self.timeStamp()} Start compiling."
        @next()
      )
      Relay.func(->
        fs.readdir self.srcDir, @next
      )
      Relay.func((err, files)->
        if err?
          console.log err
        else
          @next files
      )
      Relay.each(
        Relay.serial(
          Relay.func((file)->
            @local.basename = path.basename file, path.extname(file)
            fs.readFile path.join(self.srcDir, file), 'utf8', @next
          )
          Relay.func((err, code)->
            if err?
              @skip()
            else
              if CoffeeMill.R_ENV.test code
                node = coffee.compile(
                  code.replace CoffeeMill.R_ENV, (matched, $1, $2, offset, source)->
                    if $2? then $2 else ''
                )
                browser = coffee.compile(
                  code.replace CoffeeMill.R_ENV, (matched, $1, $2, offset, source)->
                    if $1? then $1 else ''
                )
                files = [
                  { path: "node/#{@local.basename}.js", code: node }
                  { path: "browser/#{@local.basename}.js", code: browser }
                ]
                if self.isComplress
                  files.push { path: "browser/#{@local.basename}.min.js", code: self.compress browser }
                @next files
              else
                code = coffee.compile code
                files = [
                  { path: "#{@local.basename}.js", code: code }
                ]
                if self.isComplress
                  files.push { path: "#{@local.basename}.min.js", code: self.compress code }
                @next files
          )
          Relay.each(
            Relay.serial(
              Relay.func((file)->
                @local.filename = path.join self.dstDir, file.path
                fs.writeFile @local.filename, file.code, @next
              )
              Relay.func((err)->
                if err?
                  console.log err
                  @skip()
                else
                  console.log "#{self.timeStamp()} Write file: #{@local.filename}"
                  @next()
              )
            )
          )
        )
      )
      Relay.func(->
        console.log "#{self.timeStamp()} Complete compiling."
        @next()
      )
    )
    .complete(self.test)
    .start()
  
  compress: (code)->
    uglify.ast_squeeze uglify.ast_mangle parser.parse code
  
  test: =>
    self = @
    Relay.serial(
      Relay.func(->
        fs.stat self.testDir, @next
      )
      Relay.func((err, stats)->
        unless err?
          console.log "#{self.timeStamp()} Start testing."
          nodeunit = spawn 'nodeunit', [self.testDir]
          nodeunit.stderr.setEncoding 'utf8'
          nodeunit.stderr.on 'data', (data)->
            console.log data.replace(/\s*$/, '')
          nodeunit.stdout.setEncoding 'utf8'
          nodeunit.stdout.on 'data', (data)->
            console.log data.replace(/\s*$/, '')
          nodeunit.on 'exit', (code)->
            console.log "#{self.timeStamp()} Complete testing."
        @next()
      )
    ).start()
    