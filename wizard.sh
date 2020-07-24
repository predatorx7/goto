#!/bin/env bash
usage_body="USAGE: wizard <command>

Available commands:
    install     Installs goto for this user's default SHELL 
                ($SHELL for you, $USER) (updates if already installed)
    run         Run with dart*
    build       Build binaries*
    test        Run tests*
    clean       Clean all build files
    uninstall   Remove goto from everywhere
    help        Show this help
    
*Some commands may require 'dart-sdk' installed and in environment path"

command=$1
SHELLRC=""
GOTOPATH=$HOME/.local/share/goto
GOTOFILEPATH=$GOTOPATH/.goto
GOTOFFILE=$GOTOPATH/funcgoto

GOTOFSRC="
# >>> goto >>>>
# The below line sources goto's helper function file.
# The file is necessary to let goto operate properly.
source $GOTOFFILE
# <<< goto <<<<"

# Determine shellrc file
case "${SHELL}" in
/bin/zsh)
    SHELLRC=$HOME/.zshrc
    ;;
/bin/bash)
    # Determine machine.
    case "$(uname -s)" in
    Linux*) SHELLRC=$HOME/.bashrc ;;
    Darwin*) SHELLRC=$HOME/.bash_profile ;;
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

function installer() {
    # set PATH so it includes user's private bin if it exists
    if [ -d "$HOME/bin" ]; then
        if [ -f bin/goto-cli ]; then
            cp bin/goto-cli $HOME/bin/goto-cli
            chmod +x $HOME/bin/goto-cli
        else
            echo "No pre-built binary found. Use 'wizard build'"
            exit 1
        fi
    else
        echo "ERROR: ensure $HOME/bin is in environment PATH"
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

    if grep -q "source $GOTOFFILE" "$SHELLRC"; then
        echo "Instructions to source file already exists in shell config. skipping.."
    else
        echo "$GOTOFSRC" >>$SHELLRC
    fi

    echo -e "\nInstall success"
}

function uninstaller() {
    rm -r $HOME/.local/share/goto 2>/dev/null
    rm $HOME/bin/goto-cli 2>/dev/null
    grep -v "$GOTOFSRC" "$SHELLRC" >"$SHELLRC.tmp" && mv "$SHELLRC.tmp" "$SHELLRC"
    echo -e "\nUninstalled"
}

function runner() {
    dart bin/main.dart $@;
    if [ -f "$GOTOFILEPATH" ]; then
        GOTOADD="$(cat $(echo $GOTOFILEPATH))"
        echo "Teleporting :$1: => $GOTOADD"
        echo "[Will not work in this config.]"
    fi
    rm $GOTOFILEPATH 2> /dev/null;
}

case "$command" in
install)
    installer
    ;;
build) builder ;;
run)
    shift
    runner $@
    ;;
test) dart test/goto_test.dart ;;
clean)
    rm -r ./.dart_tool 2>/dev/null
    rm bin/goto-cli 2>/dev/null
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
