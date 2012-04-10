require 'nodeunit'

coffeemill = require '../lib/coffeemill'
{Relay} = require 'relay'
path = require 'path'
fs = require 'fs'
{spawn} = require 'child_process'

INPUT = path.join __dirname, 'input'
OUTPUT = path.join __dirname, 'output'

pickUpAfter = ->
  process.nextTick ->
    Relay.serial(
      Relay.func(->
        fs.readdir OUTPUT, @next
      )
      Relay.func((err, files)->
        if err?
          @skip()
        else
          @next files
      )
      Relay.each(
        Relay.func((file)->
          fs.unlink path.join(OUTPUT, file), @next
        )
      )
    )
    .complete(->
      process.exit 0
    )
    .start()

exports.direct =

  'normal': (test)->
    coffeemill.grind INPUT, OUTPUT, null, null, false, false, true, ->
      fs.readFile path.join(OUTPUT, 'dummy.js'), 'utf8', (err, data)->
        test.strictEqual err, null
        test.strictEqual data, """
        (function() {
          var foo;

          foo = 'dummy';

        }).call(this);

        """
        test.done()

  'bare': (test)->
    coffeemill.grind INPUT, OUTPUT, null, null, true, false, true, ->
      fs.readFile path.join(OUTPUT, 'dummy.js'), 'utf8', (err, data)->
        test.strictEqual err, null
        test.strictEqual data, """
        var foo;

        foo = 'dummy';

        """
        test.done()

  'compress': (test)->
    coffeemill.grind INPUT, OUTPUT, null, null, false, true, true, ->
      fs.readFile path.join(OUTPUT, 'dummy.min.js'), 'utf8', (err, data)->
        test.strictEqual err, null
        test.strictEqual data, """
        (function(){var a;a="dummy"}).call(this)
        """
        test.done()
        pickUpAfter()
