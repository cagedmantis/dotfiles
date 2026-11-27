package dotfiles_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// runMake runs a Makefile target from the repo root with $HOME pointed at home.
func runMake(t *testing.T, home string, args ...string) (string, error) {
	t.Helper()
	if _, err := exec.LookPath("make"); err != nil {
		t.Skip("make not installed")
	}
	cmd := exec.Command("make", append([]string{"--no-print-directory"}, args...)...)
	cmd.Dir = repoRoot(t)
	cmd.Env = append(os.Environ(), "HOME="+home)
	out, err := cmd.CombinedOutput()
	return string(out), err
}

// TestMakeAdoptRequiresConfirm guards the adopt target: without CONFIRM=1 it
// must refuse before stow runs, so a stray `make adopt` cannot overwrite the
// repo with whatever is in $HOME.
func TestMakeAdoptRequiresConfirm(t *testing.T) {
	home := t.TempDir()
	if err := os.WriteFile(filepath.Join(home, ".zshrc"), []byte("mine\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	out, err := runMake(t, home, "adopt")
	if err == nil {
		t.Fatalf("make adopt without CONFIRM=1 succeeded:\n%s", out)
	}
	if !strings.Contains(out, "CONFIRM=1") {
		t.Errorf("refusal should say how to proceed, got:\n%s", out)
	}
	// Refusing must happen before stow: the real file stays a real file.
	if fi, err := os.Lstat(filepath.Join(home, ".zshrc")); err != nil || fi.Mode()&os.ModeSymlink != 0 {
		t.Errorf("~/.zshrc was touched by a refused adopt (err=%v)", err)
	}
}

// TestMakeLinkUnlinkRoundTrip checks unlink removes exactly what link made and
// leaves unrelated files alone.
func TestMakeLinkUnlinkRoundTrip(t *testing.T) {
	if _, err := exec.LookPath("stow"); err != nil {
		t.Skip("stow not installed")
	}
	home := t.TempDir()
	keep := filepath.Join(home, "keep")
	if err := os.WriteFile(keep, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	if out, err := runMake(t, home, "link"); err != nil {
		t.Fatalf("make link: %v\n%s", err, out)
	}
	for _, rel := range wantLinks {
		assertLinkedToRepo(t, home, rel)
	}
	if out, err := runMake(t, home, "unlink"); err != nil {
		t.Fatalf("make unlink: %v\n%s", err, out)
	}
	for _, rel := range wantLinks {
		if _, err := os.Lstat(filepath.Join(home, rel)); !os.IsNotExist(err) {
			t.Errorf("%s still present after unlink (err=%v)", rel, err)
		}
	}
	if _, err := os.Stat(keep); err != nil {
		t.Errorf("unlink removed an unrelated file: %v", err)
	}
}
