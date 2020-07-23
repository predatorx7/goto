# Goto

Keeps a key-value record of paths you wish to save for quick access later

## Installation

Use Wizard to install Goto.

```sh
# build (needs dart installed)
$ ./wizard.sh build

# ** recommended **
# installs goto (if build already exists)
$ ./wizard.sh install
```

## Usage

Use `goto <key>` to redirect to &lt;key&gt;'s path

or just `goto <command> [arguments]`

### Global options

-h, --help Print this usage information.

### Available commands

#### get, g

- Gets a path address matching the key

#### list, ls, l

- List all saved records in a human readable format

#### remove, rm, r

- Removes a record matching the key

#### set, save, s

- Saves a path with a key.

Run `goto help <command>` for more information about a command.

### example

```sh
### run goto help
$ goto help


### run current directory with key "games"
$ goto set games .
```

## Development

Goto command-line application has an entrypoint in `bin/` for binary & for entrypoint source, library code in `lib/`, and unit test in `test/`.

This project includes a number of helpers in the `wizard` to streamline common tasks.
