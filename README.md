# Goto

A fast, lightweight command-line tool for managing directory shortcuts and jumping instantly between folders in your terminal. Written in Go for peak performance and zero runtime dependencies.

Keeps a key-value record of paths you wish to save for quick access later.

---

## Features

- **Blazing Fast**: Native Go binary with instant startup and minimal footprint (~3MB).
- **Zero Runtime Dependencies**: No Dart, Node.js, or Python runtimes required.
- **Atomic & Safe**: Atomic storage engine prevents shortcut corruption on power loss or interruption.
- **Smart Shell Integration**: Seamlessly teleports your active shell session (`cd`).
- **Tab Completion**: Dynamic autocompletion for subcommands and your saved shortcut keys (Zsh, Bash, Fish).
- **Standards Compliant**: Adheres to the XDG Base Directory specification (`$XDG_DATA_HOME/goto`).

---

## Installation

### Standard Installation

Clone the repository and run the installer:

```sh
git clone https://github.com/predatorx7/goto.git
cd goto
./install.sh
```

Or run via one-liner:

```sh
curl -fsSL https://raw.githubusercontent.com/predatorx7/goto/master/install.sh | bash
```

After installation, reload your shell configuration (e.g. `source ~/.zshrc` or `source ~/.bashrc`) or open a new terminal window.

### Custom Prefix / Non-Interactive Installation

```sh
# Install to custom directory
./install.sh --prefix /usr/local/bin

# Non-interactive / unattended install
./install.sh --yes
```

---

## Usage

Use `goto <key>` to redirect your shell to `<key>`'s saved path, or run `goto <command> [arguments]`.

### Quick Example

```sh
# Save current directory with key "games"
$ goto set games .

# Save specific directory with key "scripts"
$ goto set scripts /home/user/Work/scripts

# Jump instantly to "games"
$ goto games
Teleporting :games: => /path/to/games

# Jump to "scripts"
$ goto scripts
Teleporting :scripts: => /home/user/Work/scripts

# List all saved shortcuts
$ goto list
games: /path/to/games
scripts: /home/user/Work/scripts
```

### Key Naming Rules

`<key>` must only contain alphanumeric characters and underscores (`a-z`, `A-Z`, `0-9`, `_`), and cannot match reserved command names or aliases.

---

## Commands & Aliases

| Command | Aliases | Description |
| :--- | :--- | :--- |
| `goto <key>` | — | Teleports shell directly to `<key>`'s path |
| `goto set <key> [path]` | `save`, `s` | Saves a directory bookmark (defaults to current dir `.` if path omitted) |
| `goto get <key>` | `g` | Prints path matching the key |
| `goto list` | `ls`, `l` | Lists all saved shortcuts in alphabetical order |
| `goto rename <old> <new>` | `re` | Renames an existing key |
| `goto remove <key>` | `rm`, `r` | Removes a saved record |
| `goto remove -a` | `rm -a` | Removes all saved records (`--all`) |
| `goto init [shell]` | — | Outputs shell integration code (`zsh`, `bash`, `fish`) |
| `goto help [command]` | `-h`, `--help`| Displays usage information |
| `goto version` | `-V`, `--version` | Displays version and author information |

---

## Development

Goto uses standard Go tooling:

```sh
# Run tests
make test
# or: go test -v ./...

# Build binary
make build
# or: go build -o bin/goto-cli ./cmd/goto-cli

# Install locally
make install

# Clean artifacts
make clean
```

---

## License

BSD 3-Clause License. See [LICENSE.md](LICENSE.md) for details.
