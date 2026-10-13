#!/usr/bin/env bash
# ==============================================================================
# goto installer
#
# Standard, robust installer script for goto CLI and shell integration.
# Supports macOS and Linux with Zsh, Bash, and Fish shells.
#
# Usage:
#   ./install.sh [command] [options]
#   curl -fsSL https://raw.githubusercontent.com/predatorx7/goto/master/install.sh | bash
# ==============================================================================

set -euo pipefail

# --- Color and formatting setup ---
BOLD=""
GREEN=""
YELLOW=""
RED=""
BLUE=""
MAGENTA=""
RESET=""

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
    BOLD="\033[1m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    RED="\033[31m"
    BLUE="\033[34m"
    MAGENTA="\033[35m"
    RESET="\033[0m"
fi

info() {
    printf "${BLUE}${BOLD}::${RESET} %s\n" "$*"
}

step() {
    printf "${MAGENTA}${BOLD}==>${RESET} ${BOLD}%s${RESET}\n" "$*"
}

success() {
    printf "${GREEN}${BOLD}✓${RESET} %s\n" "$*"
}

warn() {
    printf "${YELLOW}${BOLD}!${RESET} %s\n" "$*" >&2
}

error() {
    printf "${RED}${BOLD}✗${RESET} %s\n" "$*" >&2
}

fatal() {
    error "$*"
    exit 1
}

# --- Cleanup trap ---
TMP_FILES=()
cleanup() {
    for f in "${TMP_FILES[@]:-}"; do
        [ -f "$f" ] && rm -f "$f" 2>/dev/null || true
    done
}
trap cleanup EXIT INT TERM

# --- Defaults ---
get_version() {
    if [ -n "${SCRIPT_DIR:-}" ] && [ -d "${SCRIPT_DIR}/.git" ]; then
        local git_tag
        git_tag="$(git -C "$SCRIPT_DIR" describe --tags --exact-match 2>/dev/null || true)"
        if [ -n "$git_tag" ]; then
            echo "${git_tag#v}"
            return 0
        fi
    fi
    if [ -f "${SCRIPT_DIR}/internal/version/version.go" ]; then
        local parsed
        parsed="$(grep -E 'Version\s*=\s*"[^"]+"' "${SCRIPT_DIR}/internal/version/version.go" | sed -E 's/.*"([^"]+)".*/\1/')"
        if [ -n "$parsed" ]; then
            echo "$parsed"
            return 0
        fi
    fi
    echo "0.3.0"
}
VERSION="$(get_version)"
PREFIX="${GOTO_INSTALL_DIR:-$HOME/.local/bin}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/goto"
HELPER_FILE="$DATA_DIR/funcgoto"
NON_INTERACTIVE=false
ALLOW_ROOT=false
NO_SHELL_CONFIG=false
COMMAND=""

# Determine script root directory if executed locally
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

usage() {
    cat <<EOF
${BOLD}Goto Installer v${VERSION}${RESET}

${BOLD}USAGE:${RESET}
    ./install.sh [command] [options]

${BOLD}COMMANDS:${RESET}
    install      Build and install goto CLI + shell integration (default)
    build        Build goto-cli binary locally to ./bin/goto-cli
    test         Run Go automated test suite
    clean        Remove build artifacts
    uninstall    Remove goto binary, shell hooks, and optionally saved data
    help         Show this help message

${BOLD}OPTIONS:${RESET}
    -p, --prefix <dir>       Install directory for executable (default: $HOME/.local/bin)
    -y, --yes                Automatic yes to prompts (non-interactive mode)
    --no-shell-config        Skip updating shell rc files (~/.zshrc, ~/.bashrc, etc.)
    --allow-root             Allow running installer as root (not recommended)
    -h, --help               Show this help message

${BOLD}EXAMPLES:${RESET}
    ./install.sh
    ./install.sh --prefix /usr/local/bin
    ./install.sh uninstall
EOF
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        install|build|test|clean|uninstall|help)
            COMMAND="$1"
            shift
            ;;
        -p|--prefix)
            PREFIX="$2"
            shift 2
            ;;
        -y|--yes)
            NON_INTERACTIVE=true
            shift
            ;;
        --no-shell-config)
            NO_SHELL_CONFIG=true
            shift
            ;;
        --allow-root)
            ALLOW_ROOT=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            warn "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

if [ -z "$COMMAND" ]; then
    COMMAND="install"
fi

if [ "$COMMAND" = "help" ]; then
    usage
    exit 0
fi

# --- System & Pre-flight Checks ---
check_system() {
    # Check root execution
    if [ "$(id -u)" -eq 0 ] && [ "$ALLOW_ROOT" = false ]; then
        fatal "Installing as root is not recommended. If you really want this, pass --allow-root"
    fi

    if [ -z "${HOME:-}" ] || [ ! -d "$HOME" ]; then
        fatal "\$HOME directory does not exist or is not accessible."
    fi

    # OS check
    OS="$(uname -s)"
    case "$OS" in
        Darwin*) PLATFORM="darwin" ;;
        Linux*)  PLATFORM="linux" ;;
        *) fatal "Unsupported operating system: $OS" ;;
    esac

    # Arch check
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64|amd64)  ARCH="amd64" ;;
        arm64|aarch64) ARCH="arm64" ;;
        *) fatal "Unsupported architecture: $ARCH" ;;
    esac
}

find_go() {
    if command -v go >/dev/null 2>&1; then
        return 0
    fi
    # Check common Go installation paths on macOS and Linux
    for p in "/usr/local/go/bin" "/opt/homebrew/bin" "$HOME/go/bin"; do
        if [ -x "$p/go" ]; then
            export PATH="$p:$PATH"
            return 0
        fi
    done
    return 1
}

# --- Shell Detection & Configuration ---
detect_shell_rc() {
    local user_shell
    user_shell="$(basename "${SHELL:-zsh}")"

    case "$user_shell" in
        zsh)
            echo "$HOME/.zshrc"
            ;;
        bash)
            if [ "$PLATFORM" = "darwin" ]; then
                if [ -f "$HOME/.bash_profile" ]; then
                    echo "$HOME/.bash_profile"
                else
                    echo "$HOME/.bashrc"
                fi
            else
                echo "$HOME/.bashrc"
            fi
            ;;
        fish)
            echo "$HOME/.config/fish/config.fish"
            ;;
        *)
            echo "$HOME/.profile"
            ;;
    esac
}

START_BLOCK="# >>> goto initialize >>>"
END_BLOCK="# <<< goto initialize <<<"

update_shell_config() {
    local rc_file="$1"
    local user_shell
    user_shell="$(basename "${SHELL:-zsh}")"

    info "Configuring shell integration in $rc_file"

    if [ ! -f "$rc_file" ]; then
        mkdir -p "$(dirname "$rc_file")"
        touch "$rc_file"
    fi

    # Backup rc file
    local backup="${rc_file}.goto.bak"
    cp "$rc_file" "$backup"

    # Remove existing goto block if present
    if grep -q "$START_BLOCK" "$rc_file" 2>/dev/null; then
        sed -i.tmp "/$START_BLOCK/,/$END_BLOCK/d" "$rc_file"
        rm -f "${rc_file}.tmp" 2>/dev/null || true
    fi

    # Append fresh block
    if [ "$user_shell" = "fish" ]; then
        cat >> "$rc_file" <<EOF

$START_BLOCK
# The lines below are managed by goto installer
set -gx PATH "$PREFIX" \$PATH
test -f "$HELPER_FILE"; and source "$HELPER_FILE"
$END_BLOCK
EOF
    else
        cat >> "$rc_file" <<EOF

$START_BLOCK
# The lines below are managed by goto installer
export PATH="$PREFIX:\$PATH"
[ -f "$HELPER_FILE" ] && source "$HELPER_FILE"
$END_BLOCK
EOF
    fi

    success "Updated $rc_file (backup saved to ${backup})"
}

remove_shell_config() {
    local rc_file="$1"
    if [ -f "$rc_file" ] && grep -q "$START_BLOCK" "$rc_file" 2>/dev/null; then
        info "Removing goto integration block from $rc_file"
        sed -i.tmp "/$START_BLOCK/,/$END_BLOCK/d" "$rc_file"
        rm -f "${rc_file}.tmp" 2>/dev/null || true
        success "Cleaned $rc_file"
    fi
}

# --- Action Implementations ---
do_build() {
    step "Building goto-cli..."
    if ! find_go; then
        fatal "Go compiler ('go') not found in PATH or standard locations.\nPlease install Go (1.20+) to build goto from source."
    fi

    local root_dir="${SCRIPT_DIR:-.}"
    if [ ! -f "$root_dir/cmd/goto-cli/main.go" ]; then
        fatal "Source directory $root_dir does not contain cmd/goto-cli/main.go"
    fi

    mkdir -p "$root_dir/bin"
    local ver
    ver="$(get_version)"
    local commit
    commit="$(git -C "$root_dir" rev-parse --short HEAD 2>/dev/null || echo "")"
    local ldflags="-s -w -X github.com/predatorx7/goto/internal/version.Version=${ver}"
    if [ -n "$commit" ]; then
        ldflags="$ldflags -X github.com/predatorx7/goto/internal/version.GitCommit=${commit}"
    fi

    (
        cd "$root_dir"
        go build -ldflags "$ldflags" -o ./bin/goto-cli ./cmd/goto-cli
    )
    success "Binary built at $root_dir/bin/goto-cli"
}

do_test() {
    step "Running automated tests..."
    if ! find_go; then
        fatal "Go compiler not found."
    fi

    local root_dir="${SCRIPT_DIR:-.}"
    (
        cd "$root_dir"
        go test -v ./...
    )
    success "All tests passed!"
}

do_clean() {
    step "Cleaning build artifacts..."
    local root_dir="${SCRIPT_DIR:-.}"
    rm -rf "$root_dir/bin" "$root_dir/.dart_tool"
    success "Clean complete."
}

do_install() {
    check_system

    step "[1/4] Preparing installation directories..."
    mkdir -p "$PREFIX"
    mkdir -p "$DATA_DIR"
    success "Install path: $PREFIX"
    success "Data directory: $DATA_DIR"

    step "[2/4] Compiling goto-cli executable..."
    local root_dir="${SCRIPT_DIR:-.}"
    if [ -f "$root_dir/cmd/goto-cli/main.go" ]; then
        do_build
        cp "$root_dir/bin/goto-cli" "$PREFIX/goto-cli"
    elif [ -f "$root_dir/bin/goto-cli" ]; then
        cp "$root_dir/bin/goto-cli" "$PREFIX/goto-cli"
    else
        fatal "Could not find source or prebuilt binary to install."
    fi
    chmod +x "$PREFIX/goto-cli"
    success "Installed executable to $PREFIX/goto-cli"

    step "[3/4] Generating shell helper & completions..."
    local user_shell
    user_shell="$(basename "${SHELL:-zsh}")"
    "$PREFIX/goto-cli" init "$user_shell" > "$HELPER_FILE"
    chmod 644 "$HELPER_FILE"
    success "Generated helper script at $HELPER_FILE"

    step "[4/4] Configuring shell..."
    local rc_file
    rc_file="$(detect_shell_rc)"
    if [ "$NO_SHELL_CONFIG" = false ]; then
        update_shell_config "$rc_file"
    else
        info "Skipping shell rc file modification (--no-shell-config enabled)."
    fi

    echo ""
    printf "${GREEN}${BOLD}======================================================${RESET}\n"
    printf "${GREEN}${BOLD}     🎉 Goto v%s successfully installed!              ${RESET}\n" "$VERSION"
    printf "${GREEN}${BOLD}======================================================${RESET}\n\n"

    printf "${BOLD}To start using goto, restart your shell or run:${RESET}\n"
    printf "  ${CYAN:-}source %s${RESET}\n\n" "$rc_file"

    printf "${BOLD}Quick start:${RESET}\n"
    printf "  ${BOLD}goto set work ~/Projects/work${RESET}   # Save directory bookmark\n"
    printf "  ${BOLD}goto work${RESET}                       # Jump to bookmark\n"
    printf "  ${BOLD}goto list${RESET}                       # List all bookmarks\n"
    printf "  ${BOLD}goto --help${RESET}                     # View all commands\n\n"
}

do_uninstall() {
    check_system
    step "Uninstalling goto..."

    # 1. Remove binary
    if [ -f "$PREFIX/goto-cli" ]; then
        rm -f "$PREFIX/goto-cli"
        success "Removed $PREFIX/goto-cli"
    fi

    # 2. Clean shell configs
    for f in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.config/fish/config.fish" "$HOME/.profile"; do
        remove_shell_config "$f"
    done

    # 3. Handle data directory
    if [ -d "$DATA_DIR" ]; then
        local remove_data=false
        if [ "$NON_INTERACTIVE" = true ]; then
            remove_data=true
        else
            printf "\n"
            read -r -p "Do you want to delete all saved bookmarks in $DATA_DIR? [y/N]: " reply
            if [[ "$reply" =~ ^[Yy]$ ]]; then
                remove_data=true
            fi
        fi

        if [ "$remove_data" = true ]; then
            rm -rf "$DATA_DIR"
            success "Removed data directory $DATA_DIR"
        else
            info "Preserved data directory $DATA_DIR"
        fi
    fi

    success "Goto has been completely uninstalled."
}

# --- Execute Command ---
case "$COMMAND" in
    install)   do_install ;;
    build)     do_build ;;
    test)      do_test ;;
    clean)     do_clean ;;
    uninstall) do_uninstall ;;
    *)
        error "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac
