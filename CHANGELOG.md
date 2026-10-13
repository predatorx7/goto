# Goto

## 0.3.0

- Complete high-performance rewrite in Go (Golang) adhering to standard Go project layout and best practices.
- Zero runtime dependencies: single self-contained native binary.
- Atomic storage engine with safe JSON persistence to prevent file corruption.
- Automatic shell completion (tab completion) for commands and saved shortcut keys in Zsh, Bash, and Fish.
- Comprehensive unit and integration test suite across all modules.
- Modern installer script (`install.sh`) following standard best practices from tools like Homebrew, Rustup, and Starship.
- Added Makefile support for standard build, test, install, format, and cleanup targets.
- Added `--allow-root` flag for root environments when explicitly requested.

## 0.2.0

- Update dependencies

## 0.1.0

- Migrate to null safety

## 0.0.7

- Option to install goto from latest tag

## 0.0.6

- Command to rename keys
- Only accept legal key names (which must also not include any command names)
- Prompt before removing save files when uninstalling via wizard.sh
- Fix: wizard Uninstaller can't remove source line with comments from shell user-config file (bashrc, zshrc)

## 0.0.5

- Fix env & portability issues
- Avoid installation for root

## 0.0.4

- Version & developer information
- Clarified goto sourcing usage
- Updated help message in wizard
- Colored error messages

## 0.0.3

- Improvements in wizard.sh
- Fixed a missed future's error handling

## 0.0.2

- Hide log & stacks on uncaught exceptions
- Option to remove all saved information in one command (use remove [-a|--all])

## 0.0.1

- Tested initial release. Works on Ubuntu.
