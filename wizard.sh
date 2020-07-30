#!/usr/bin/env bash

if [ "$(basename $HOME)" == root ]; then
    echo "ERROR: Cannot install for root"
    exit 1
fi

if [ ! -d "$HOME" ]; then
    echo "\$HOME does not exist. Cannot install."
    exit 1
fi

DEFAULT_SHELL="$(basename $SHELL)"

usage_body="USAGE: wizard <command>

Available commands:
    install     Installs goto (updates if already installed)
    run         Run with dart*
    installb    Installs build
    build       Build binaries*
    test        Run tests*
    clean       Clean all build files
    uninstall   Remove goto from everywhere
    help        Show this help

'$DEFAULT_SHELL' is your default shell, $USER
*Some commands may require 'dart-sdk' installed and in environment path"

command=$1
SHELL_CONFIG_FILE=""
GOTOPATH=$HOME/.local/share/goto
GOTOFILEPATH=$GOTOPATH/.goto
GOTOFFILE=$GOTOPATH/funcgoto

GOTOFSRC="
# >>> goto >>>>
# The below line sources goto's helper function file.
# The file is necessary to let goto operate properly.
source $GOTOFFILE
# <<< goto <<<<"

GOTOFSRC_array=(
    "# >>> goto >>>>"
    "# The below line sources goto's helper function file."
    "# The file is necessary to let goto operate properly."
    "source $GOTOFFILE"
    "# <<< goto <<<<"
)

# Determine shellrc file
case "${DEFAULT_SHELL}" in
zsh)
    SHELL_CONFIG_FILE=$HOME/.zshrc
    ;;
bash)
    # Determine machine.
    case "$(uname -s)" in
    Linux*) SHELL_CONFIG_FILE=$HOME/.bashrc ;;
    Darwin*)
        SHELL_CONFIG_FILE=$HOME/.bash_profile
        ;;
    *)
        echo "Machine ${unameOut} not supported"
        exit 1
        ;;
    esac
    ;;
*)
    echo "Shell not supported"
    exit 1
    ;;
esac

if [[ ! -f "$SHELL_CONFIG_FILE" ]]; then
    echo "$SHELL_CONFIG_FILE does not exist. Creating it now.."
    touch "$SHELL_CONFIG_FILE"
fi

function usage() {
    echo "$usage_body"
}

function builder() {
    pub get
    dart2native bin/main.dart -o bin/goto-cli
}

function switchToLatest() {
    cd "$(dirname "$0")"
    git checkout --quiet master 2>/dev/null
    git pull --quiet origin master 2>/dev/null
    latesttag=$(git describe --tags)
    echo switching to ${latesttag}
    git checkout --quiet ${latesttag} 2>/dev/null
}

function installer() {
    # set PATH so it includes user's private bin if it exists
    if [[ :$PATH: != *:"$HOME/.local/bin":* ]]; then
        echo "ERROR: $HOME/.local/bin is not in environment PATH"
        exit 1
    fi
    mkdir -p "$HOME/.local/bin"
    mkdir -p "$GOTOPATH"
    if [ -f bin/goto-cli ]; then
        GOTOLOC_BIN="$HOME/.local/bin/goto-cli"
        if [ -f "$GOTOLOC_BIN" ]; then
            # remove old installed bin
            rm "$GOTOLOC_BIN" 2>/dev/null
        fi
        cp bin/goto-cli $GOTOLOC_BIN
        chmod +x $GOTOLOC_BIN
    else
        echo "Binary executable 'goto-cli' not found in bin/"
        exit 1
    fi

    gotofunc="
function goto(){
    goto-cli \$@;
    if [ -f "$GOTOFILEPATH" ]; then
        GOTOADD=\"\$(cat $(echo $GOTOFILEPATH))\"
        echo \"Teleporting :\$1: => \$GOTOADD\"
        cd \"\$GOTOADD\";
    fi
    rm $GOTOFILEPATH 2> /dev/null;
}"

    echo "$gotofunc" >$GOTOFFILE

    if grep -q "source $GOTOFFILE" "$SHELL_CONFIG_FILE"; then
        echo "Instructions to source goto function file already exists in shell config. skipping.."
    else
        echo "$GOTOFSRC" >>$SHELL_CONFIG_FILE
    fi

    echo -e "\nInstall success"
}

function removeSourcingInformation() {
    for line in "${GOTOFSRC_array[@]}"; do
        grep -v "$line" "$SHELL_CONFIG_FILE" >"$SHELL_CONFIG_FILE.tmp" && mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"
    done
}

function uninstaller() {
    if [[ -d "$HOME/.local/share/goto" ]]; then
        read -p "This will remove all saved key-paths. Are you sure? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -r $HOME/.local/share/goto 2>/dev/null
        fi
    fi
    rm $HOME/bin/goto-cli 2>/dev/null
    rm $HOME/.local/bin/goto-cli 2>/dev/null
    removeSourcingInformation
    echo -e "\nUninstalled"
}

function runner() {
    dart bin/main.dart $@
    if [ -f "$GOTOFILEPATH" ]; then
        GOTOADD="$(cat $(echo $GOTOFILEPATH))"
        echo "With key '$1', the current directory must change to $GOTOADD if goto was installed"
        echo "[Will not work in this run]"
    fi
    rm $GOTOFILEPATH 2>/dev/null
}

function cleanup() {
    echo "cleaning"
    if [ -d ".dart_tool" ]; then
        rm -r .dart_tool
        echo "removed .dart_tool"
    fi
    if [ -f "bin/goto-cli" ]; then
        rm bin/goto-cli 2>/dev/null
        echo "removed bin/goto-cli"
    fi
}

case "$command" in
install)
    switchToLatest
    installer
    git switch --quiet - 2>/dev/null
    ;;
installb)
    installer
    ;;
build) builder ;;
run)
    shift
    runner $@
    ;;
test) dart test/goto_test.dart ;;
clean)
    cleanup
    ;;
uninstall)
    uninstaller
    ;;
help) usage ;;
*)
    echo -e "ERROR: Unknown argument\n"
    usage
    ;;
esac
