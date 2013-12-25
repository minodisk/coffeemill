module.exports = (grunt) ->
  grunt.initConfig

    pkg: grunt.file.readJSON 'package.json'

    watch:
      bin:
        files: [
          'src/bin/*.coffee'
        ]
        tasks: [ 'coffee:bin', 'concat:bin', 'clean:bin' ]
      lib:
        files: [
          'src/lib/*.coffee'
          'tests/*.coffee'
          'tests/src/**/*.coffee'
          'tests/src/**/*.js'
        ]
        tasks: [ 'coffee:lib', 'coffee:tests', 'mocha:tests', 'clean:tests' ]

    coffee:
      bin:
        options:
          bare: true
        files: [
          expand: true
          cwd: 'src/bin'
          src: [ '*.coffee' ]
          dest: 'bin'
          ext: '.js'
        ]
      lib:
        files: [
          expand: true
          cwd: 'src/lib'
          src: [ '*.coffee' ]
          dest: 'lib'
          ext: '.js'
        ]
      tests:
        files: [
          expand: true
          src: ['tests/*.coffee']
          ext: '.js'
        ]

    concat:
      bin:
        options:
          banner: '#!/usr/bin/env node\n\n'
        src: [ 'bin/coffeemill.js' ]
        dest: 'bin/coffeemill'

    clean:
      bin: [ 'bin/*.js' ]
      tests: [ 'tests/*.js' ]

    mochaTest:
      tests: ['tests/**/*_tests.js']


  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-concat'
  grunt.loadNpmTasks 'grunt-contrib-clean'
  grunt.loadNpmTasks 'grunt-mocha-test'

  grunt.registerTask 'compile', [ 'coffee:bin', 'concat:bin', 'clean:bin', 'coffee:lib', 'coffee:tests', 'mochaTest:tests', 'clean:tests' ]
  grunt.registerTask 'default', [ 'compile', 'watch' ]