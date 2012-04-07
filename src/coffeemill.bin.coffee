`#!/usr/bin/env node`

do ->
  {CoffeeMill} = require '../lib/coffeemill'
  coffeemill = new CoffeeMill()
  argv = process.argv
  for arg in argv
    switch arg
      when '-v', '--version'
        console.log CoffeeMill.version()
        return
      when '-h', '--help'
        console.log CoffeeMill.help()
        return
      when '-o', '--out'
        flag = 'o'
      when '-t', '--test'
        flag = 't'
      when '-c', '--compress'
        compress = true
      else
        switch flag
          when 's'
            srcDir = arg
          when 'o'
            dstDir = arg
          when 't'
            testDir = arg
  coffeemill.grind srcDir, dstDir, testDir, compress