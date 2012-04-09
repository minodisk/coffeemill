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

* `-o, --output [DIR]` : Write out all compiled JavaScript files into the specified directory. Default is `lib`.
* `-t, --test [DIR]` : Run all test JavaScript or CoffeeScript files with [nodeunit](https://github.com/caolan/nodeunit) in the specified directory. Default is `test`.
* `-c, --compress` : Compress the compiled JavaScript with [UglifyJS](https://github.com/mishoo/UglifyJS).
* `-b, --bare` : Compile the JavaScript without a top-level function wrapper.
* `-j, --join [FILE]` : Before compiling, concatenate all scripts together in the order they were passed, and write them into the specified file.
* `-h, --help` : Display this help message.
* `-v, --version` : Display the version number.

## TODO

* Add '-p', '--project' option. Create project automatically.
