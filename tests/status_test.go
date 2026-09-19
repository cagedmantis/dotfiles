package dotfiles_test

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// runStatus executes scripts/status.sh against the given $HOME and returns its
// combined output and exit status.
//
// The script is run with an explicit /bin/sh rather than by path so the test
// exercises it as a POSIX script regardless of the executable bit or of what
// the ambient $SHELL happens to be.
func runStatus(t *testing.T, home string) (string, int) {
	t.Helper()
	root := repoRoot(t)

	cmd := exec.Command("/bin/sh", filepath.Join(root, "scripts", "status.sh"))
	cmd.Dir = root
	cmd.Env = append(os.Environ(), "HOME="+home)
	out, err := cmd.CombinedOutput()
	if err == nil {
		return string(out), 0
	}
	var ee *exec.ExitError
	if errors.As(err, &ee) {
		return string(out), ee.ExitCode()
	}
	t.Fatalf("running status.sh: %v\n%s", err, out)
	return "", -1
}

// stowInto builds a throwaway $HOME of its own, installed the way `make link`
// does. The shared sandbox() cannot be used by tests that mutate $HOME: it is
// built once per binary and every other test reads from it.
func stowInto(t *testing.T) string {
	t.Helper()
	root := repoRoot(t)
	home := t.TempDir()

	cmd := exec.Command("stow", "--no-folding", "--target="+home, ".")
	cmd.Dir = root
	cmd.Env = append(os.Environ(), "HOME="+home)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("stow into %s: %v\n%s", home, err, out)
	}
	return home
}

// TestStatusOnUnlinkedHome is the question the target exists to answer: a
// machine that has never run `make link` must be reported as such, and must
// exit non-zero so the answer is usable from a script.
func TestStatusOnUnlinkedHome(t *testing.T) {
	out, code := runStatus(t, t.TempDir())

	if !strings.Contains(out, "NOT LINKED") {
		t.Errorf("fresh $HOME should report NOT LINKED, got:\n%s", out)
	}
	if code == 0 {
		t.Errorf("fresh $HOME should exit non-zero, got 0:\n%s", out)
	}
	// The whole point is naming what is missing, not just the verdict.
	if !strings.Contains(out, ".zshrc") {
		t.Errorf("output should name the unlinked files, got:\n%s", out)
	}
}

// TestStatusOnLinkedHome is the same check from the other side. Without it, a
// script that always answered "NOT LINKED" would pass the test above.
func TestStatusOnLinkedHome(t *testing.T) {
	out, code := runStatus(t, sandbox(t))

	if !strings.Contains(out, "status: LINKED") {
		t.Errorf("stowed $HOME should report LINKED, got:\n%s", out)
	}
	if code != 0 {
		t.Errorf("stowed $HOME should exit 0, got %d:\n%s", code, out)
	}
	if strings.Contains(out, "missing") || strings.Contains(out, "conflict") {
		t.Errorf("stowed $HOME should report no problems, got:\n%s", out)
	}
}

// TestStatusOnPartiallyLinkedHome covers the state a machine actually drifts
// into: linked months ago, then a new dotfile was added to the repo and never
// stowed. "Ever linked" is true, "up to date" is not, and the two must not be
// reported as the same thing.
func TestStatusOnPartiallyLinkedHome(t *testing.T) {
	home := stowInto(t)
	if err := os.Remove(filepath.Join(home, ".zshrc")); err != nil {
		t.Fatalf("removing a link to simulate drift: %v", err)
	}

	out, code := runStatus(t, home)

	if !strings.Contains(out, "PARTIALLY LINKED") {
		t.Errorf("a $HOME missing one link should report PARTIALLY LINKED, got:\n%s", out)
	}
	if code == 0 {
		t.Errorf("partially linked $HOME should exit non-zero, got 0:\n%s", out)
	}
	if !strings.Contains(out, "missing   .zshrc") {
		t.Errorf("output should name .zshrc as missing, got:\n%s", out)
	}
}

// TestStatusDistinguishesConflictFromMissing guards the advice, not just the
// classification: stow refuses the whole install rather than overwrite a real
// file, so telling the user to run `make link` when a conflict is in the way
// sends them in a circle.
func TestStatusDistinguishesConflictFromMissing(t *testing.T) {
	home := stowInto(t)
	zshrc := filepath.Join(home, ".zshrc")
	if err := os.Remove(zshrc); err != nil {
		t.Fatalf("removing link: %v", err)
	}
	if err := os.WriteFile(zshrc, []byte("# a real file, not a link\n"), 0o644); err != nil {
		t.Fatalf("writing conflicting file: %v", err)
	}

	out, code := runStatus(t, home)

	if !strings.Contains(out, "conflict  .zshrc") {
		t.Errorf("a real file in the way should be reported as a conflict, got:\n%s", out)
	}
	if strings.Contains(out, "missing   .zshrc") {
		t.Errorf("a real file in the way is a conflict, not a missing link, got:\n%s", out)
	}
	if code == 0 {
		t.Errorf("conflicting $HOME should exit non-zero, got 0:\n%s", out)
	}
}

// TestStatusIgnoresForeignSymlinks checks that a link to some other tree is not
// counted as installed. Someone migrating from another dotfiles repo has links
// with the right names pointing at the wrong place, and calling that "linked"
// would be the one wrong answer that matters.
func TestStatusIgnoresForeignSymlinks(t *testing.T) {
	home := stowInto(t)
	zshrc := filepath.Join(home, ".zshrc")
	if err := os.Remove(zshrc); err != nil {
		t.Fatalf("removing link: %v", err)
	}
	other := filepath.Join(t.TempDir(), ".zshrc")
	if err := os.WriteFile(other, []byte("# another tree\n"), 0o644); err != nil {
		t.Fatalf("writing foreign file: %v", err)
	}
	if err := os.Symlink(other, zshrc); err != nil {
		t.Fatalf("linking to another tree: %v", err)
	}

	out, code := runStatus(t, home)

	if !strings.Contains(out, "foreign   .zshrc") {
		t.Errorf("a link into another tree should be reported as foreign, got:\n%s", out)
	}
	if code == 0 {
		t.Errorf("foreign link should exit non-zero, got 0:\n%s", out)
	}
}

// TestStatusResolvesRelativeLinks is a regression guard for the resolution
// logic. Stow writes relative links (~/.config/fish/config.fish points at
// ../../../<repo>/.config/fish/config.fish), and BSD readlink has no -f, so the
// script resolves them by hand against the link's own directory. A nested path
// is where that arithmetic goes wrong, and it must not read as foreign.
func TestStatusResolvesRelativeLinks(t *testing.T) {
	home := sandbox(t)

	target, err := os.Readlink(filepath.Join(home, ".config/fish/config.fish"))
	if err != nil {
		t.Fatalf("reading the link stow created: %v", err)
	}
	if filepath.IsAbs(target) {
		t.Skipf("stow wrote an absolute link (%s); the relative path is not under test here", target)
	}

	out, _ := runStatus(t, home)
	if strings.Contains(out, "config.fish") {
		t.Errorf("the nested relative link should resolve as linked, but it was flagged:\n%s", out)
	}
}
