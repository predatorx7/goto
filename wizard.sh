#!/usr/bin/env bash

if [ "$(basename $HOME)" == root ]; then
    echo "ERROR: Cannot install for root"
    exit 1
fi

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

('$SHELL' is your default shell, $USER)
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

DEFAULT_SHELL="$(basename "$(grep "^$USER" /etc/passwd)")"

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
        if [[ ! -f "$SHELL_CONFIG_FILE" ]]; then
            echo "~/.bash_profile does not exist. Creating it now.."
            touch "$SHELL_CONFIG_FILE"
        fi
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

function usage() {
    echo "$usage_body"
}

function builder() {
    pub get
    dart2native bin/main.dart -o bin/goto-cli
}

function switchToLatest() {
    cd "$(dirname "$0")"
    git checkout master 2>/dev/null
    git pull origin master 2>/dev/null
    latesttag=$(git describe --tags) 2>/dev/null
    echo switching to ${latesttag}
    git checkout ${latesttag} 2>/dev/null
    git switch - 2>/dev/null
}

function installer() {
    # set PATH so it includes user's private bin if it exists
    if [ -d "$HOME/.local/bin" ]; then
        if [ -f bin/goto-cli ]; then
            if [ -f $HOME/bin/goto-cli ]; then
                # remove old installed bin
                rm $HOME/bin/goto-cli 2>/dev/null
            fi
            cp bin/goto-cli $HOME/.local/bin/goto-cli
            chmod +x $HOME/.local/bin/goto-cli
        else
            echo "No pre-built binary found. Use 'wizard build'"
            exit 1
        fi
    else
        echo "ERROR: ensure $HOME/.local/bin exists & is in environment PATH"
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

    mkdir "$GOTOPATH" 2>/dev/null
    echo "$gotofunc" >$GOTOFFILE

    if grep -q "source $GOTOFFILE" "$SHELL_CONFIG_FILE"; then
        echo "Instructions to source file already exists in shell config. skipping.."
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
        echo # (optional) move to a new line
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
        echo "With key '$1', the directory must change to $GOTOADD if goto was installed"
        echo "[Will not work in this run]"
    fi
    rm $GOTOFILEPATH 2>/dev/null
}

function cleanup() {
    echo "Removing unnecessary files"
    if [ -d ".dart_tool" ]; then
        rm -r .dart_tool
    fi
    if [ -f "bin/goto-cli" ]; then
        rm bin/goto-cli 2>/dev/null
    fi
}

case "$command" in
install)
    switchToLatest
    installer
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
