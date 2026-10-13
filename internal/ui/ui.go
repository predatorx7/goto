package ui

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strings"
)

const (
	colorReset        = "\033[0m"
	colorBold         = "\033[1m"
	colorYellowItalic = "\033[33;3m"
	colorLightRed     = "\033[91m"
	colorGreen        = "\033[32m"
)

// UI manages terminal output formatting, colors, and user interaction.
type UI struct {
	Out      io.Writer
	Err      io.Writer
	In       io.Reader
	UseColor bool
}

// New creates a new UI with standard I/O streams and automatic color detection.
func New() *UI {
	useColor := isColorSupported(os.Stdout)
	return &UI{
		Out:      os.Stdout,
		Err:      os.Stderr,
		In:       os.Stdin,
		UseColor: useColor,
	}
}

// NewCustom creates a UI instance with custom streams and explicit color setting (ideal for tests).
func NewCustom(out, err io.Writer, in io.Reader, useColor bool) *UI {
	return &UI{
		Out:      out,
		Err:      err,
		In:       in,
		UseColor: useColor,
	}
}

func isColorSupported(f *os.File) bool {
	if os.Getenv("NO_COLOR") != "" {
		return false
	}
	if os.Getenv("TERM") == "dumb" {
		return false
	}

	fi, err := f.Stat()
	if err != nil {
		return false
	}
	// Check if file is a character device (terminal)
	return (fi.Mode() & os.ModeCharDevice) != 0
}

func (u *UI) style(text, code string) string {
	if !u.UseColor || code == "" {
		return text
	}
	return code + text + colorReset
}

// GotoError prints a yellow italic error prefixed with [Goto] (matching original Dart behavior).
func (u *UI) GotoError(reason string) {
	msg := fmt.Sprintf("[Goto] %s", reason)
	fmt.Fprintln(u.Err, u.style(msg, colorYellowItalic))
}

// Warn prints a yellow italic warning message.
func (u *UI) Warn(msg string) {
	fmt.Fprintln(u.Err, u.style(msg, colorYellowItalic))
}

// ExitError prints an error message in light red.
func (u *UI) ExitError(msg string) {
	fmt.Fprintln(u.Err, u.style(msg, colorLightRed))
}

// MissingArgs prints usage and arguments missing error in light red.
func (u *UI) MissingArgs(usage string) {
	if usage != "" {
		fmt.Fprintf(u.Err, "%s\n\n", usage)
	}
	missing := "ERROR: Arguments missing "
	fmt.Fprintln(u.Err, u.style(missing, colorLightRed))
}

// Info prints regular text to standard output.
func (u *UI) Info(msg string) {
	fmt.Fprintln(u.Out, msg)
}

// PromptConfirm asks the user a yes/no question and returns true if accepted.
func (u *UI) PromptConfirm(prompt string) (bool, error) {
	fmt.Fprint(u.Out, prompt)
	reader := bufio.NewReader(u.In)
	line, err := reader.ReadString('\n')
	if err != nil && err != io.EOF {
		return false, err
	}
	trimmed := strings.TrimSpace(line)
	if len(trimmed) > 0 && (trimmed[0] == 'y' || trimmed[0] == 'Y') {
		return true, nil
	}
	return false, nil
}
