package dotfiles_test

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// runForceLink executes scripts/force-link.sh against the given $HOME and
// returns its combined output and exit status.
func runForceLink(t *testing.T, home string) (string, int) {
	t.Helper()
	root := repoRoot(t)

	cmd := exec.Command("/bin/sh", filepath.Join(root, "scripts", "force-link.sh"))
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
	t.Fatalf("running force-link.sh: %v\n%s", err, out)
	return "", -1
}

// assertLinkedToRepo fails unless home/rel is a symlink resolving to the
// repo's copy of rel.
func assertLinkedToRepo(t *testing.T, home, rel string) {
	t.Helper()
	root, err := filepath.EvalSymlinks(repoRoot(t))
	if err != nil {
		t.Fatal(err)
	}
	p := filepath.Join(home, rel)
	fi, err := os.Lstat(p)
	if err != nil {
		t.Fatalf("%s: %v", rel, err)
	}
	if fi.Mode()&os.ModeSymlink == 0 {
		t.Fatalf("%s is not a symlink", rel)
	}
	got, err := filepath.EvalSymlinks(p)
	if err != nil {
		t.Fatalf("%s: %v", rel, err)
	}
	if want := filepath.Join(root, rel); got != want {
		t.Errorf("%s resolves to %s, want %s", rel, got, want)
	}
}

func readFile(t *testing.T, p string) string {
	t.Helper()
	b, err := os.ReadFile(p)
	if err != nil {
		t.Fatalf("reading %s: %v", p, err)
	}
	return string(b)
}

// TestForceLinkMovesConflictsAside is the target's reason to exist: every
// kind of occupant stow refuses is renamed to .bak with its contents intact,
// and the install then completes.
func TestForceLinkMovesConflictsAside(t *testing.T) {
	home := t.TempDir()

	// A real file, including one in a nested directory.
	if err := os.WriteFile(filepath.Join(home, ".zshrc"), []byte("mine\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	fish := filepath.Join(home, ".config/fish")
	if err := os.MkdirAll(fish, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(fish, "config.fish"), []byte("my fish\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	// A link into another tree.
	other := filepath.Join(t.TempDir(), "bashrc")
	if err := os.WriteFile(other, []byte("other tree\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(other, filepath.Join(home, ".bashrc")); err != nil {
		t.Fatal(err)
	}
	// A dangling link.
	if err := os.Symlink(filepath.Join(home, "nowhere"), filepath.Join(home, ".profile")); err != nil {
		t.Fatal(err)
	}
	// A directory where a file belongs.
	if err := os.MkdirAll(filepath.Join(home, ".tmux.conf/sub"), 0o755); err != nil {
		t.Fatal(err)
	}

	out, code := runForceLink(t, home)
	if code != 0 {
		t.Fatalf("force-link exited %d:\n%s", code, out)
	}

	for _, rel := range wantLinks {
		assertLinkedToRepo(t, home, rel)
	}
	if got := readFile(t, filepath.Join(home, ".zshrc.bak")); got != "mine\n" {
		t.Errorf(".zshrc.bak = %q, want the original contents", got)
	}
	if got := readFile(t, filepath.Join(fish, "config.fish.bak")); got != "my fish\n" {
		t.Errorf("config.fish.bak = %q, want the original contents", got)
	}
	if target, err := os.Readlink(filepath.Join(home, ".bashrc.bak")); err != nil || target != other {
		t.Errorf(".bashrc.bak should be the original link to %s, got %q (%v)", other, target, err)
	}
	if _, err := os.Lstat(filepath.Join(home, ".profile.bak")); err != nil {
		t.Errorf("the dangling link should have been moved to .profile.bak: %v", err)
	}
	if fi, err := os.Stat(filepath.Join(home, ".tmux.conf.bak/sub")); err != nil || !fi.IsDir() {
		t.Errorf("the .tmux.conf directory should have been moved whole: %v", err)
	}
}

// TestForceLinkOnLinkedHomeIsNoop checks that rerunning on a linked machine
// makes no backups: an already-correct link is not a conflict.
func TestForceLinkOnLinkedHomeIsNoop(t *testing.T) {
	home := stowInto(t)

	out, code := runForceLink(t, home)
	if code != 0 {
		t.Fatalf("force-link exited %d:\n%s", code, out)
	}
	if strings.Contains(out, "moved") {
		t.Errorf("a linked $HOME should need no moves, got:\n%s", out)
	}
	matches, _ := filepath.Glob(filepath.Join(home, "*.bak"))
	if len(matches) > 0 {
		t.Errorf("unexpected backups: %v", matches)
	}
}

// TestForceLinkRefusesToOverwriteBackup guards the one way this could lose
// data: a .bak left by an earlier run. It must stop before changing anything,
// including the other conflicts it could have moved safely.
func TestForceLinkRefusesToOverwriteBackup(t *testing.T) {
	home := t.TempDir()
	files := map[string]string{
		".zshrc":     "current\n",
		".zshrc.bak": "older backup\n",
		".bashrc":    "unrelated conflict\n",
	}
	for name, body := range files {
		if err := os.WriteFile(filepath.Join(home, name), []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	out, code := runForceLink(t, home)
	if code == 0 {
		t.Fatalf("force-link should refuse when a backup exists, got 0:\n%s", out)
	}
	if !strings.Contains(out, ".zshrc.bak") {
		t.Errorf("output should name the existing backup, got:\n%s", out)
	}
	for name, body := range files {
		if got := readFile(t, filepath.Join(home, name)); got != body {
			t.Errorf("%s changed to %q; nothing should be touched on refusal", name, got)
		}
	}
	if _, err := os.Lstat(filepath.Join(home, ".bashrc.bak")); err == nil {
		t.Error(".bashrc was moved even though the run was refused")
	}
}

// TestForceLinkNeverRenamesRepoFiles guards a $HOME folded by an older stow
// run without --no-folding: ~/.config is a link to the repo's .config, so
// ~/.config/fish/config.fish is a real file that *is* the repo's copy. Moving
// it "aside" would rename a tracked file inside the repo.
func TestForceLinkNeverRenamesRepoFiles(t *testing.T) {
	root := repoRoot(t)
	home := t.TempDir()

	cmd := exec.Command("stow", "--target="+home, ".") // folding, deliberately
	cmd.Dir = root
	cmd.Env = append(os.Environ(), "HOME="+home)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("folded stow: %v\n%s", err, out)
	}
	if fi, err := os.Lstat(filepath.Join(home, ".config")); err != nil || fi.Mode()&os.ModeSymlink == 0 {
		t.Skip("stow did not fold .config; the scenario under test did not arise")
	}

	out, _ := runForceLink(t, home)

	if _, err := os.Lstat(filepath.Join(root, ".config/fish/config.fish.bak")); err == nil {
		os.Rename(filepath.Join(root, ".config/fish/config.fish.bak"), filepath.Join(root, ".config/fish/config.fish"))
		t.Fatalf("force-link renamed a file inside the repo (restored):\n%s", out)
	}
	if _, err := os.Stat(filepath.Join(root, ".config/fish/config.fish")); err != nil {
		t.Fatalf("the repo's config.fish is gone: %v\n%s", err, out)
	}
}

// TestForceLinkRollsBackWhenStowFails covers a conflict this script does not
// move: ~/.config as a regular file blocks a directory, not a file. Stow then
// fails, and the renames already made must be undone rather than left behind.
func TestForceLinkRollsBackWhenStowFails(t *testing.T) {
	home := t.TempDir()
	if err := os.WriteFile(filepath.Join(home, ".config"), []byte("a file\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(home, ".zshrc"), []byte("mine\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	out, code := runForceLink(t, home)
	if code == 0 {
		t.Fatalf("force-link should fail when stow does, got 0:\n%s", out)
	}
	if got := readFile(t, filepath.Join(home, ".zshrc")); got != "mine\n" {
		t.Errorf(".zshrc = %q after rollback, want the original restored", got)
	}
	if _, err := os.Lstat(filepath.Join(home, ".zshrc.bak")); err == nil {
		t.Error(".zshrc.bak left behind after rollback")
	}
}

// TestForceLinkNamesWhatItMoved checks the output says which files were
// renamed. Moves happen silently otherwise, and the user needs the list to go
// and merge anything worth keeping from the .bak copies.
func TestForceLinkNamesWhatItMoved(t *testing.T) {
	home := t.TempDir()
	if err := os.WriteFile(filepath.Join(home, ".zshrc"), []byte("mine\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	out, code := runForceLink(t, home)
	if code != 0 {
		t.Fatalf("force-link exited %d:\n%s", code, out)
	}
	if !strings.Contains(out, "moved     .zshrc -> .zshrc.bak") {
		t.Errorf("output should name the moved file, got:\n%s", out)
	}
	if strings.Contains(out, ".bashrc") {
		t.Errorf("output should name only files that were moved, got:\n%s", out)
	}
}

// TestForceLinkWithoutStow checks the script fails loudly, and before
// touching anything, when stow is missing. Without the check, the dry run
// would list no files and every later step would silently do nothing.
func TestForceLinkWithoutStow(t *testing.T) {
	// A PATH with the base utilities but not stow, which is a package
	// install and so never lives in /bin.
	const path = "/usr/bin:/bin"
	for _, d := range filepath.SplitList(path) {
		if _, err := os.Stat(filepath.Join(d, "stow")); err == nil {
			t.Skipf("stow is installed in %s; cannot hide it", d)
		}
	}
	home := t.TempDir()
	zshrc := filepath.Join(home, ".zshrc")
	if err := os.WriteFile(zshrc, []byte("mine\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	cmd := exec.Command("/bin/sh", filepath.Join(repoRoot(t), "scripts", "force-link.sh"))
	cmd.Env = []string{"HOME=" + home, "PATH=" + path}
	out, err := cmd.CombinedOutput()
	if err == nil {
		t.Fatalf("force-link should fail without stow, got success:\n%s", out)
	}
	if !strings.Contains(string(out), "stow is not installed") {
		t.Errorf("output should say stow is missing, got:\n%s", out)
	}
	if got := readFile(t, zshrc); got != "mine\n" {
		t.Errorf(".zshrc changed to %q; nothing should be touched", got)
	}
}

// TestStatusAgreesAfterForceLink checks the two scripts agree end to end:
// once force-link succeeds on a $HOME full of conflicts, status must report
// the machine as linked. They share lib.sh, and this catches them drifting
// apart on what "linked" means.
func TestStatusAgreesAfterForceLink(t *testing.T) {
	home := t.TempDir()
	for _, name := range []string{".zshrc", ".bashrc", ".profile"} {
		if err := os.WriteFile(filepath.Join(home, name), []byte("mine\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	if out, code := runForceLink(t, home); code != 0 {
		t.Fatalf("force-link exited %d:\n%s", code, out)
	}
	out, code := runStatus(t, home)
	if code != 0 || !strings.Contains(out, "status: LINKED") {
		t.Errorf("status after force-link should report LINKED and exit 0, got %d:\n%s", code, out)
	}
}

// TestMakeForceLink checks the Makefile target is wired to the script. The
// tests above run the script directly, so a typo in the recipe would
// otherwise go unnoticed.
func TestMakeForceLink(t *testing.T) {
	if _, err := exec.LookPath("make"); err != nil {
		t.Skip("make not installed")
	}
	home := t.TempDir()
	if err := os.WriteFile(filepath.Join(home, ".zshrc"), []byte("mine\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	cmd := exec.Command("make", "--no-print-directory", "force-link")
	cmd.Dir = repoRoot(t)
	cmd.Env = append(os.Environ(), "HOME="+home)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("make force-link: %v\n%s", err, out)
	}
	assertLinkedToRepo(t, home, ".zshrc")
	if got := readFile(t, filepath.Join(home, ".zshrc.bak")); got != "mine\n" {
		t.Errorf(".zshrc.bak = %q, want the original contents", got)
	}
}
