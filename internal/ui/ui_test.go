package ui

import (
	"bytes"
	"strings"
	"testing"
)

func TestUIOutput(t *testing.T) {
	out := &bytes.Buffer{}
	errOut := &bytes.Buffer{}
	in := strings.NewReader("y\n")

	u := NewCustom(out, errOut, in, false)

	u.GotoError("something failed")
	if !strings.Contains(errOut.String(), "[Goto] something failed") {
		t.Errorf("expected '[Goto] something failed', got %q", errOut.String())
	}

	errOut.Reset()
	u.Warn("warning text")
	if !strings.Contains(errOut.String(), "warning text") {
		t.Errorf("expected 'warning text', got %q", errOut.String())
	}

	errOut.Reset()
	u.ExitError("fatal error")
	if !strings.Contains(errOut.String(), "fatal error") {
		t.Errorf("expected 'fatal error', got %q", errOut.String())
	}

	errOut.Reset()
	u.MissingArgs("usage: goto set <key>")
	if !strings.Contains(errOut.String(), "usage: goto set <key>") || !strings.Contains(errOut.String(), "ERROR: Arguments missing") {
		t.Errorf("expected usage and error message, got %q", errOut.String())
	}

	ok, err := u.PromptConfirm("Continue? (Y/n): ")
	if err != nil || !ok {
		t.Fatalf("expected confirm true, got %v (err=%v)", ok, err)
	}
}

func TestPromptConfirmNegative(t *testing.T) {
	out := &bytes.Buffer{}
	errOut := &bytes.Buffer{}
	in := strings.NewReader("n\n")

	u := NewCustom(out, errOut, in, false)
	ok, err := u.PromptConfirm("Continue? (Y/n): ")
	if err != nil || ok {
		t.Fatalf("expected confirm false, got %v (err=%v)", ok, err)
	}
}
