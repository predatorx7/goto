package app

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/predatorx7/goto/internal/config"
	"github.com/predatorx7/goto/internal/shell"
	"github.com/predatorx7/goto/internal/store"
	"github.com/predatorx7/goto/internal/ui"
	"github.com/predatorx7/goto/internal/version"
)

var keyPattern = regexp.MustCompile(`^[a-zA-Z0-9_]+$`)

var illegalKeyNames = map[string]bool{
	"g":          true,
	"get":        true,
	"ls":         true,
	"l":          true,
	"list":       true,
	"re":         true,
	"rename":     true,
	"rm":         true,
	"r":          true,
	"remove":     true,
	"save":       true,
	"s":          true,
	"set":        true,
	"help":       true,
	"version":    true,
	"init":       true,
	"completion": true,
}

// App encapsulates the goto CLI application logic.
type App struct {
	cfg   *config.Config
	store *store.Store
	ui    *ui.UI
	pwd   string
}

// New creates an App instance with standard configuration and UI.
func New() (*App, error) {
	cfg, err := config.New()
	if err != nil {
		return nil, err
	}
	st := store.NewStore(cfg.DataFile)
	pwd, _ := os.Getwd()
	return &App{
		cfg:   cfg,
		store: st,
		ui:    ui.New(),
		pwd:   pwd,
	}, nil
}

// NewCustom creates an App instance with custom configuration, store, UI, and working directory (ideal for testing).
func NewCustom(cfg *config.Config, st *store.Store, u *ui.UI, pwd string) *App {
	return &App{
		cfg:   cfg,
		store: st,
		ui:    u,
		pwd:   pwd,
	}
}

// Run executes the command line application with the provided arguments.
// It returns an exit code (0 for success, 1 for user/domain errors, 2 for syntax errors).
func (a *App) Run(args []string) int {
	if err := a.store.Load(); err != nil {
		a.ui.ExitError(err.Error())
		return 1
	}

	if len(args) == 0 {
		a.printUsage()
		return 0
	}

	first := args[0]

	// Global flags
	switch first {
	case "-h", "--help":
		a.printUsage()
		return 0
	case "-V", "--version", "version":
		a.ui.Info(version.Full())
		return 0
	case "--keys-only":
		return a.runListKeysOnly()
	}

	// Commands and aliases
	switch first {
	case "help":
		if len(args) > 1 {
			a.printCommandUsage(args[1])
		} else {
			a.printUsage()
		}
		return 0

	case "set", "save", "s":
		return a.runSet(args[1:])

	case "get", "g":
		return a.runGet(args[1:])

	case "list", "ls", "l":
		return a.runList(args[1:])

	case "remove", "rm", "r":
		return a.runRemove(args[1:])

	case "rename", "re":
		return a.runRename(args[1:])

	case "init":
		return a.runInit(args[1:])

	default:
		// If multiple unknown arguments are supplied
		if len(args) > 1 {
			a.ui.ExitError(fmt.Sprintf("Could not find a command named %q.\nRun 'goto --help' for available commands.", first))
			return 1
		}
		// Single argument represents a key navigation: goto <key>
		return a.runGo(first)
	}
}

func (a *App) validateKey(key string) error {
	if !keyPattern.MatchString(key) {
		a.ui.Warn(fmt.Sprintf("'%s' has invalid format. Key must only contain alphabet, underscore, or numbers", key))
		return errors.New("invalid key format")
	}
	if illegalKeyNames[key] {
		a.ui.Warn(fmt.Sprintf("'%s' is invalid. Key must not be the name or alias of any goto command.", key))
		return errors.New("reserved key name")
	}
	return nil
}

func (a *App) runGo(key string) int {
	destPath, ok := a.store.Get(key)
	if !ok {
		a.ui.GotoError(fmt.Sprintf("Key '%s' not assigned to any path", key))
		return 1
	}

	fi, err := os.Stat(destPath)
	if err != nil || !fi.IsDir() {
		a.ui.Warn(fmt.Sprintf("'%s' not found. It either does not exist or is not a directory.", destPath))
		return 1
	}

	if err := a.cfg.EnsureDataDir(); err != nil {
		a.ui.GotoError("An unexpected error occurred")
		return 1
	}

	if err := os.WriteFile(a.cfg.MarkerFile, []byte(destPath), 0644); err != nil {
		a.ui.GotoError("An unexpected error occurred")
		return 1
	}

	return 0
}

func (a *App) runSet(args []string) int {
	usage := "goto set <key> <path>\n\nOther alias: save, s"

	var force bool
	filteredArgs := make([]string, 0, len(args))
	for _, arg := range args {
		if arg == "-f" || arg == "--force" {
			force = true
		} else {
			filteredArgs = append(filteredArgs, arg)
		}
	}

	if len(filteredArgs) == 0 {
		a.ui.MissingArgs(usage)
		return 1
	}

	key := filteredArgs[0]
	if err := a.validateKey(key); err != nil {
		return 1
	}

	var targetDir string
	if len(filteredArgs) == 1 || filteredArgs[1] == "." {
		targetDir = a.pwd
	} else {
		targetDir = filteredArgs[1]
	}

	if !filepath.IsAbs(targetDir) {
		absPath, err := filepath.Abs(filepath.Join(a.pwd, targetDir))
		if err == nil {
			targetDir = absPath
		}
	}
	targetDir = filepath.Clean(targetDir)

	fi, err := os.Stat(targetDir)
	if err != nil || !fi.IsDir() {
		a.ui.Warn(fmt.Sprintf("'%s' not found. It either does not exist or is not a directory.", targetDir))
		return 1
	}

	if existingPath, exists := a.store.Get(key); exists && !force {
		prompt := fmt.Sprintf("A path saved with '%s' already exists. This will remove '%s' from entries.\nDo you wish to continue? (Y/n): ", key, existingPath)
		confirmed, err := a.ui.PromptConfirm(prompt)
		if err != nil || !confirmed {
			return 0
		}
	}

	a.ui.Info(fmt.Sprintf("Saving %q with key %q.. ", targetDir, key))
	if err := a.store.Set(key, targetDir); err != nil {
		a.ui.ExitError(err.Error())
		return 1
	}

	return 0
}

func (a *App) runGet(args []string) int {
	usage := "goto get <key>\n\nOther alias: g"
	if len(args) == 0 {
		a.ui.MissingArgs(usage)
		return 1
	}

	key := args[0]
	path, ok := a.store.Get(key)
	if !ok {
		a.ui.GotoError(fmt.Sprintf("Found no path with '%s' key", key))
		return 1
	}

	a.ui.Info(fmt.Sprintf("%s -> %s", key, path))
	return 0
}

func (a *App) runList(args []string) int {
	for _, arg := range args {
		if arg == "--keys-only" || arg == "-k" {
			return a.runListKeysOnly()
		}
	}

	entries := a.store.List()
	if len(entries) == 0 {
		a.ui.Info("No saved records")
		return 0
	}

	for _, entry := range entries {
		a.ui.Info(fmt.Sprintf("%s: %s", entry.Key, entry.Path))
	}
	return 0
}

func (a *App) runListKeysOnly() int {
	entries := a.store.List()
	for _, entry := range entries {
		a.ui.Info(entry.Key)
	}
	return 0
}

func (a *App) runRemove(args []string) int {
	usage := "goto remove <key>\n\nOther alias: rm, r"

	removeAll := false
	var key string
	for _, arg := range args {
		if arg == "-a" || arg == "--all" {
			removeAll = true
		} else if key == "" {
			key = arg
		}
	}

	if removeAll {
		if err := a.store.DeleteAll(); err != nil {
			a.ui.ExitError(err.Error())
			return 1
		}
		return 0
	}

	if key == "" {
		a.ui.MissingArgs(usage)
		return 1
	}

	if _, err := a.store.Delete(key); err != nil {
		a.ui.ExitError(err.Error())
		return 1
	}
	return 0
}

func (a *App) runRename(args []string) int {
	usage := "goto rename <previous_key_name> <new_key_name>\n\nOther alias: re"

	var force bool
	filtered := make([]string, 0, len(args))
	for _, arg := range args {
		if arg == "-f" || arg == "--force" {
			force = true
		} else {
			filtered = append(filtered, arg)
		}
	}

	if len(filtered) < 2 {
		a.ui.MissingArgs(usage)
		return 1
	}

	oldKey := filtered[0]
	newKey := filtered[1]

	oldPath, exists := a.store.Get(oldKey)
	if !exists {
		a.ui.GotoError(fmt.Sprintf("Found no path with '%s' key", oldKey))
		return 1
	}

	if oldKey == newKey {
		a.ui.ExitError("Error: Old & new key names must not be same.")
		return 1
	}

	if err := a.validateKey(newKey); err != nil {
		return 1
	}

	if existingPath, exists := a.store.Get(newKey); exists && !force {
		prompt := fmt.Sprintf("A path saved with '%s' already exists. This will remove '%s' from entries.\nDo you wish to continue? (Y/n): ", newKey, existingPath)
		confirmed, err := a.ui.PromptConfirm(prompt)
		if err != nil || !confirmed {
			return 0
		}
	}

	a.ui.Info(fmt.Sprintf("Renaming key '%s' with '%s'.. ", oldKey, newKey))
	if err := a.store.Set(newKey, oldPath); err != nil {
		a.ui.ExitError(err.Error())
		return 1
	}
	if _, err := a.store.Delete(oldKey); err != nil {
		a.ui.ExitError(err.Error())
		return 1
	}

	return 0
}

func (a *App) runInit(args []string) int {
	shellType := "zsh"
	if len(args) > 0 {
		shellType = args[0]
	} else {
		// Detect from SHELL environment variable
		sh := os.Getenv("SHELL")
		if strings.Contains(sh, "bash") {
			shellType = "bash"
		} else if strings.Contains(sh, "fish") {
			shellType = "fish"
		}
	}

	script := shell.GenerateShellScript(shellType, a.cfg.MarkerFile)
	a.ui.Info(script)
	return 0
}

func (a *App) printUsage() {
	usage := `Goto keeps a key-value record of paths you wish to save for quick access later.

Use "goto <key>" to redirect to <key>'s path

Usage: goto <command> [arguments]

Global options:
-h, --help       Print this usage information.
-V, --version    Output version information and exit

Available commands:
  get      Gets a path address matching the key (alias: g)
  list     List all saved records in a human readable format (alias: ls, l)
  remove   Removes a record matching the key (alias: rm, r)
  rename   Renames a key (alias: re)
  set      Saves a path with a key (alias: save, s)
  init     Output shell integration code for your shell

Run "goto help <command>" for more information about a command.`
	a.ui.Info(usage)
}

func (a *App) printCommandUsage(cmd string) {
	switch cmd {
	case "get", "g":
		a.ui.Info("goto get <key>\n\nGets a path address matching the key\nOther alias: g")
	case "list", "ls", "l":
		a.ui.Info("goto list\n\nList all saved records in a human readable format\nOther alias: ls, l")
	case "remove", "rm", "r":
		a.ui.Info("goto remove <key>\n\nRemoves a record matching the key\nOther alias: rm, r\nOptions:\n  -a, --all    Remove all saved key-value records")
	case "rename", "re":
		a.ui.Info("goto rename <previous_key_name> <new_key_name>\n\nRenames a key\nOther alias: re")
	case "set", "save", "s":
		a.ui.Info("goto set <key> <path>\n\nSaves a path with a key\nOther alias: save, s")
	case "init":
		a.ui.Info("goto init [bash|zsh|fish]\n\nOutput shell integration code for your shell")
	default:
		a.ui.Info(fmt.Sprintf("Unknown command %q.\nRun 'goto --help' for available commands.", cmd))
	}
}
