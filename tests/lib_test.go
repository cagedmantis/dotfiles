package dotfiles_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

// runLib sources scripts/lib.sh in /bin/sh, from the repo root as its callers
// do, and runs script after it. It returns stdout and whether sh exited 0.
func runLib(t *testing.T, script string, extraEnv ...string) (string, bool) {
	t.Helper()
	cmd := exec.Command("/bin/sh", "-c", ". scripts/lib.sh\n"+script)
	cmd.Dir = repoRoot(t)
	cmd.Env = append(append(os.Environ(), "HOME="+t.TempDir()), extraEnv...)
	var stderr strings.Builder
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		if _, ok := err.(*exec.ExitError); !ok {
			t.Fatalf("running lib.sh: %v", err)
		}
	}
	if stderr.Len() > 0 {
		t.Errorf("unexpected stderr from lib.sh:\n%s", stderr.String())
	}
	return string(out), err == nil
}

// TestExpectedFilesMatchesAllowList ties the list both scripts act on to the
// allow-list in stow_test.go. If expected_files drifted from what stow
// installs, status.sh would misreport and force-link.sh would miss conflicts.
func TestExpectedFilesMatchesAllowList(t *testing.T) {
	out, ok := runLib(t, "expected_files")
	if !ok {
		t.Fatalf("expected_files failed:\n%s", out)
	}
	got := lines(out)
	sort.Strings(got)
	want := append([]string(nil), wantLinks...)
	sort.Strings(want)

	if strings.Join(got, "\n") != strings.Join(want, "\n") {
		t.Errorf("expected_files listed the wrong files\ngot:\n  %s\nwant:\n  %s",
			strings.Join(got, "\n  "), strings.Join(want, "\n  "))
	}
}

// TestExpectedFilesCleansUp checks the dry run's scratch target is removed.
// Both scripts call this on every run, so a leak would accumulate in $TMPDIR.
func TestExpectedFilesCleansUp(t *testing.T) {
	tmp := t.TempDir()
	if _, ok := runLib(t, "expected_files >/dev/null", "TMPDIR="+tmp); !ok {
		t.Fatal("expected_files failed")
	}
	left, err := os.ReadDir(tmp)
	if err != nil {
		t.Fatal(err)
	}
	if len(left) > 0 {
		t.Errorf("expected_files left %d entries in $TMPDIR, e.g. %s", len(left), left[0].Name())
	}
}

// TestResolve covers the link shapes resolve() must handle without
// readlink -f. A wrong answer makes status.sh call a correct link foreign and
// makes force-link.sh move it to .bak.
func TestResolve(t *testing.T) {
	// EvalSymlinks because resolve() answers with pwd -P, and on macOS the
	// temp directory lives behind the /var -> /private/var link.
	dir, err := filepath.EvalSymlinks(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	mkdir := func(rel string) {
		if err := os.MkdirAll(filepath.Join(dir, rel), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	touch := func(rel string) {
		if err := os.WriteFile(filepath.Join(dir, rel), nil, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	link := func(target, rel string) {
		if err := os.Symlink(target, filepath.Join(dir, rel)); err != nil {
			t.Fatal(err)
		}
	}

	mkdir("repo/.config/fish")
	touch("repo/.zshrc")
	touch("repo/.config/fish/config.fish")
	mkdir("home/.config/fish")
	touch("home/plain")

	link("../repo/.zshrc", "home/.zshrc")                                           // relative, as stow writes it
	link("../../../repo/.config/fish/config.fish", "home/.config/fish/config.fish") // relative, nested
	link(filepath.Join(dir, "repo/.zshrc"), "home/abs")                             // absolute
	link("../repo/gone", "home/dangling")                                           // dangling, directory exists
	link("../nodir/gone", "home/nodir")                                             // dangling, directory missing

	tests := []struct {
		name string
		path string
		want string // "" means resolve must fail
	}{
		{"relative", "home/.zshrc", "repo/.zshrc"},
		{"nested relative", "home/.config/fish/config.fish", "repo/.config/fish/config.fish"},
		{"absolute", "home/abs", "repo/.zshrc"},
		{"dangling", "home/dangling", "repo/gone"},
		{"dangling into missing dir", "home/nodir", ""},
		{"not a link", "home/plain", ""},
		{"does not exist", "home/missing", ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// The path goes in as $1, not spliced into the script.
			cmd := exec.Command("/bin/sh", "-c", `. scripts/lib.sh; resolve "$1"`, "sh", filepath.Join(dir, tt.path))
			cmd.Dir = repoRoot(t)
			got, err := cmd.Output()
			if tt.want == "" {
				if err == nil {
					t.Errorf("resolve should fail, printed %q", got)
				}
				return
			}
			if err != nil {
				t.Fatalf("resolve failed: %v", err)
			}
			if want := filepath.Join(dir, tt.want); strings.TrimSpace(string(got)) != want {
				t.Errorf("resolve = %q, want %q", strings.TrimSpace(string(got)), want)
			}
		})
	}
}
