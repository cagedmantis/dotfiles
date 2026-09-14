package dotfiles_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"testing"
)

// wantLinks is the complete set of files `make link` may place in $HOME.
//
// This is an allow-list on purpose. The bug it guards (TODO #1) was that GNU
// Stow only reads <package>/.stow-local-ignore or ~/.stow-global-ignore, and
// this repo shipped a .stow-global-ignore *inside the package*, where stow
// never looks. On a fresh machine that silently symlinked ~/.bash_history,
// ~/.zsh_history, ~/.DS_Store, ~/Makefile and a file inside the real ~/.claude.
// A deny-list would have to predict each new stray file; an allow-list fails
// closed the moment anything unexpected appears.
var wantLinks = []string{
	".bash_logout",
	".bash_profile",
	".bashrc",
	".config/fish/config.fish",
	".profile",
	".tmux.conf",
	".zshenv",
	".zshrc",
}

var linkRe = regexp.MustCompile(`^LINK: (\S+)`)

// TestStowLinksOnlyExpected runs a dry-run install into an empty $HOME and
// compares what stow would create against wantLinks.
func TestStowLinksOnlyExpected(t *testing.T) {
	root := repoRoot(t)
	home := t.TempDir()

	cmd := exec.Command("stow", "--no", "--verbose=2", "--no-folding", "--target="+home, ".")
	cmd.Dir = root
	// HOME is what makes this a fresh-machine simulation: stow consults
	// $HOME/.stow-global-ignore, and here there is none.
	cmd.Env = append(os.Environ(), "HOME="+home)
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("stow dry run: %v\n%s", err, out)
	}

	var got []string
	for _, l := range lines(string(out)) {
		if m := linkRe.FindStringSubmatch(l); m != nil {
			got = append(got, m[1])
		}
	}
	sort.Strings(got)
	want := append([]string(nil), wantLinks...)
	sort.Strings(want)

	if strings.Join(got, "\n") != strings.Join(want, "\n") {
		t.Errorf("stow would link the wrong set of files\ngot:\n  %s\nwant:\n  %s",
			strings.Join(got, "\n  "), strings.Join(want, "\n  "))
	}
}

// TestStowIgnoresSensitiveFiles states the most important cases by name, so a
// failure reads as "shell history would be symlinked into a git worktree"
// rather than as an opaque set difference.
func TestStowIgnoresSensitiveFiles(t *testing.T) {
	root := repoRoot(t)
	home := t.TempDir()

	cmd := exec.Command("stow", "--no", "--verbose=2", "--no-folding", "--target="+home, ".")
	cmd.Dir = root
	cmd.Env = append(os.Environ(), "HOME="+home)
	out, _ := cmd.CombinedOutput()

	mustNotLink := []string{
		".bash_history", ".zsh_history", // credential-bearing
		".claude",   // live Claude Code config
		".DS_Store", // macOS noise
		"Makefile",  // repo scaffolding
		"README.md", "TODO.md", "CLAUDE.md",
		".gitignore", ".stow-local-ignore", ".stow-global-ignore",
		"tests",
	}
	for _, l := range lines(string(out)) {
		m := linkRe.FindStringSubmatch(l)
		if m == nil {
			continue
		}
		for _, bad := range mustNotLink {
			if m[1] == bad || strings.HasPrefix(m[1], bad+"/") {
				t.Errorf("stow would link %q into $HOME; it must be in .stow-local-ignore", m[1])
			}
		}
	}
}

// TestStowDoesNotFoldDirectories guards TODO #2. Without --no-folding, stow
// symlinks a whole directory when the target does not already exist, so
// ~/.config/fish becomes a link into the repo and fish then writes
// fish_variables, fish_history and generated completions straight into git.
func TestStowDoesNotFoldDirectories(t *testing.T) {
	home := sandbox(t) // built with --no-folding, as `make link` does

	for _, dir := range []string{".config", ".config/fish"} {
		p := filepath.Join(home, dir)
		fi, err := os.Lstat(p)
		if err != nil {
			t.Errorf("%s: %v", dir, err)
			continue
		}
		if fi.Mode()&os.ModeSymlink != 0 {
			target, _ := os.Readlink(p)
			t.Errorf("%s is a symlink to %s; it must be a real directory, or programs will write into the repo", dir, target)
		}
	}

	// The file inside it, by contrast, must be a symlink back to the repo.
	cfg := filepath.Join(home, ".config/fish/config.fish")
	fi, err := os.Lstat(cfg)
	if err != nil {
		t.Fatalf("config.fish: %v", err)
	}
	if fi.Mode()&os.ModeSymlink == 0 {
		t.Error("config.fish is not a symlink; it should point back into the repo")
	}
}

// TestStowIsIdempotent checks that re-running the install on an already-stowed
// $HOME reports no conflicts, which is what `make link` does on every machine
// after the first.
func TestStowIsIdempotent(t *testing.T) {
	root := repoRoot(t)
	home := sandbox(t)

	cmd := exec.Command("stow", "--no", "--restow", "--no-folding", "--target="+home, ".")
	cmd.Dir = root
	cmd.Env = append(os.Environ(), "HOME="+home)
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("restow: %v\n%s", err, out)
	}
	for _, l := range lines(string(out)) {
		if strings.Contains(strings.ToLower(l), "conflict") {
			t.Errorf("restow reported a conflict: %s", l)
		}
	}
}
