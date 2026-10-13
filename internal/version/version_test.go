package version

import (
	"strings"
	"testing"
)

func TestVersionString(t *testing.T) {
	v := String()
	if v == "" {
		t.Errorf("expected non-empty version string")
	}

	full := Full()
	if !strings.Contains(full, "Goto v") {
		t.Errorf("expected Full() to contain 'Goto v', got %q", full)
	}
	if !strings.Contains(full, "Syed Mushaheed") {
		t.Errorf("expected Full() to contain author name")
	}
}
