package shell

import (
	"strings"
	"testing"
)

func TestGenerateShellScript(t *testing.T) {
	marker := "/tmp/test/.goto"

	zshScript := GenerateShellScript("zsh", marker)
	if !strings.Contains(zshScript, marker) {
		t.Errorf("expected zsh script to contain marker %s", marker)
	}
	if !strings.Contains(zshScript, "compdef _goto_completion goto") {
		t.Errorf("expected zsh script to contain completion setup")
	}

	bashScript := GenerateShellScript("bash", marker)
	if !strings.Contains(bashScript, marker) {
		t.Errorf("expected bash script to contain marker %s", marker)
	}
	if !strings.Contains(bashScript, "complete -F _goto_completions goto") {
		t.Errorf("expected bash script to contain completion setup")
	}

	fishScript := GenerateShellScript("fish", marker)
	if !strings.Contains(fishScript, marker) {
		t.Errorf("expected fish script to contain marker %s", marker)
	}
	if !strings.Contains(fishScript, "complete -c goto") {
		t.Errorf("expected fish script to contain fish completion setup")
	}
}
