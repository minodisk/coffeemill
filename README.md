# CoffeeMill

Compiles CoffeeScript with some options automatically, when something changes in watching directory.

## Installation

    $ npm install -g coffeemill

## Usage

    $ coffeemill

When watching directory is 'cs'

    $ coffeemill cs

You can use some options.

    $ coffeemill -o js -t tests -c cs

* `-v`, `--version` : print coffeemill's version
* `-h`, `--help`    : print coffeemill's help
* `-o`, `--output`  : output directory (DEFAULT lib)
* `-t`, `--test`    : test directory (DEFAULT test)
