# CoffeeMill

Compiles CoffeeScript with some options automatically, when something changes in watching directory.

## Installation

    $ npm install -g coffeemill

## Usage

    $ coffeemill

When watching directory is 'source'

    $ coffeemill source

You can use some options.

    $ coffeemill -o js -t tests -c source

* `-v, --version` : Display the version number.
* `-h, --help` : Display this help message.
* `-s, --silent` : Run without displaying log.
* `-j, --join [FILE]` : Before compiling, concatenate all scripts together in the order they were passed, and write them into the specified file.
* `-b, --bare` : Compile the JavaScript without a top-level function wrapper.
* `-m, --minify` : Minify the compiled JavaScript with [UglifyJS](https://github.com/mishoo/UglifyJS).
* `-o, --output [DIR]` : Write out all compiled JavaScript files into the specified directory. Default is `lib`.
* `-t, --test [DIR]` : Run all test JavaScript or CoffeeScript files with [nodeunit](https://github.com/caolan/nodeunit) in the specified directory.
* `-c, --command '[COMMAND]'` : Run command after all processing is finished.

## TODO

* Add '-p', '--project' option. Create project automatically.
