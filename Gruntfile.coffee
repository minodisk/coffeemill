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
        ]
        tasks: 'coffee:lib'

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

    concat:
      bin:
        options:
          banner: '#!/usr/bin/env node\n\n'
        src: [ 'bin/coffeemill.js' ]
        dest: 'bin/coffeemill'

    clean:
      bin: [ 'bin/*.js' ]

  grunt.loadNpmTasks 'grunt-contrib-watch'
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-concat'
  grunt.loadNpmTasks 'grunt-contrib-clean'

  grunt.registerTask 'compile', [ 'coffee:bin', 'concat:bin', 'clean:bin', 'coffee:lib' ]
  grunt.registerTask 'default', [ 'compile', 'watch' ]