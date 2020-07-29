# Goto

Keeps a key-value record of paths you wish to save for quick access later

## Installation

Use Wizard to install Goto.

Just enter the below line in your terminal.

```sh
./wizard.sh install
```

This will do a regular installation for the latest version of goto.

---

You can also build and install goto from any commit of this repository

```sh
# build (needs dart installed)
$ ./wizard.sh build

# installs goto (if bin/goto-cli already exists)
$ ./wizard.sh installb
```

## Usage

&lt;key&gt; must only have alphabets, numbers, underscore and it should not be any command name or an alias of any command.

Use `goto <key>` to redirect to &lt;key&gt;'s path

or just `goto <command> [arguments]`

### Global options

-h, --help Prints usage information.

### Available commands (with their aliases)

#### get, g

- Gets a path address matching the key

#### list, ls, l

- List all saved records in a human readable format

#### remove, rm, r

- Removes a record matching the key

#### rename, re

- Renames a key

#### set, save, s

- Saves a path with a key.

Run `goto help <command>` for more information about a command.

### example

```sh
### run goto help
$ goto help

### Save current directory with key "games"
$ goto set games .

### Save directory with key "scr"
$ goto set scr /home/xyz/Work/scripts
```

## Development

Goto command-line application has an entrypoint in `bin/` for binary & for entrypoint source, library code in `lib/`, and unit test in `test/`.

This project includes a number of helpers in the `wizard` to streamline common tasks.
