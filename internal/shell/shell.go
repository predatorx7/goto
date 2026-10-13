package shell

import (
	"fmt"
	"strings"
)

// GenerateShellScript generates the shell helper function and completions for the specified shell.
func GenerateShellScript(shellType, markerPath string) string {
	shellType = strings.ToLower(strings.TrimSpace(shellType))
	switch shellType {
	case "fish":
		return generateFishScript(markerPath)
	case "bash":
		return generateBashScript(markerPath)
	case "zsh":
		return generateZshScript(markerPath)
	default:
		// Default to posix/bash/zsh compatible
		return generateZshScript(markerPath)
	}
}

func generateZshScript(markerPath string) string {
	return fmt.Sprintf(`#!/usr/bin/env zsh
# goto shell integration for Zsh

function goto() {
    goto-cli "$@"
    local ec=$?
    if [ $ec -ne 0 ]; then
        return $ec
    fi
    local marker="%s"
    if [ -f "$marker" ]; then
        local goto_dest
        goto_dest="$(cat "$marker")"
        rm -f "$marker" 2>/dev/null
        if [ -n "$goto_dest" ] && [ -d "$goto_dest" ]; then
            echo "Teleporting :$1: => $goto_dest"
            cd "$goto_dest" || return 1
        fi
    fi
}

# Zsh tab completion
if type compdef >/dev/null 2>&1; then
    _goto_completion() {
        local -a commands
        commands=(
            'set:Saves a path with a key'
            'get:Gets a path address matching the key'
            'list:List all saved records in a human readable format'
            'remove:Removes a record matching the key'
            'rename:Renames a key'
            'help:Prints usage information'
            'version:Output version information'
        )
        if (( CURRENT == 2 )); then
            local -a keys
            keys=(${(f)"$(goto-cli list --keys-only 2>/dev/null)"})
            _describe -t commands 'goto commands' commands
            _describe -t keys 'saved shortcuts' keys
        elif (( CURRENT == 3 )); then
            case "$words[2]" in
                get|g|remove|rm|r|rename|re)
                    local -a keys
                    keys=(${(f)"$(goto-cli list --keys-only 2>/dev/null)"})
                    _describe -t keys 'saved shortcuts' keys
                    ;;
            esac
        fi
    }
    compdef _goto_completion goto
fi
`, markerPath)
}

func generateBashScript(markerPath string) string {
	return fmt.Sprintf(`#!/usr/bin/env bash
# goto shell integration for Bash

function goto() {
    goto-cli "$@"
    local ec=$?
    if [ $ec -ne 0 ]; then
        return $ec
    fi
    local marker="%s"
    if [ -f "$marker" ]; then
        local goto_dest
        goto_dest="$(cat "$marker")"
        rm -f "$marker" 2>/dev/null
        if [ -n "$goto_dest" ] && [ -d "$goto_dest" ]; then
            echo "Teleporting :$1: => $goto_dest"
            cd "$goto_dest" || return 1
        fi
    fi
}

# Bash tab completion
if type complete >/dev/null 2>&1; then
    _goto_completions() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        local prev="${COMP_WORDS[COMP_CWORD-1]}"
        local commands="get list remove rename set help version"

        if [ "$COMP_CWORD" -eq 1 ]; then
            local keys="$(goto-cli list --keys-only 2>/dev/null)"
            COMPREPLY=($(compgen -W "$commands $keys" -- "$cur"))
        elif [ "$COMP_CWORD" -eq 2 ]; then
            case "$prev" in
                get|g|remove|rm|r|rename|re)
                    local keys="$(goto-cli list --keys-only 2>/dev/null)"
                    COMPREPLY=($(compgen -W "$keys" -- "$cur"))
                    ;;
            esac
        fi
    }
    complete -F _goto_completions goto
fi
`, markerPath)
}

func generateFishScript(markerPath string) string {
	return fmt.Sprintf(`function goto --description 'Navigate to saved bookmark'
    goto-cli $argv
    set -l ec $status
    if test $ec -ne 0
        return $ec
    end
    set -l marker "%s"
    if test -f $marker
        set -l goto_dest (cat $marker)
        rm -f $marker 2>/dev/null
        if test -n "$goto_dest"; and test -d "$goto_dest"
            echo "Teleporting :$argv[1]: => $goto_dest"
            cd $goto_dest
        end
    end
end

complete -c goto -f -a '(goto-cli list --keys-only 2>/dev/null)' -n '__fish_use_subcommand'
complete -c goto -f -a 'set get list remove rename help version' -n '__fish_use_subcommand'
`, markerPath)
}
