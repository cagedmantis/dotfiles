package dotfiles_test

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"testing"
	"time"
)

// manifestEntry is one plugin line of scripts/tmux-plugins.txt.
type manifestEntry struct{ dir, url, commit string }

func readManifest(t *testing.T, file string) []manifestEntry {
	t.Helper()
	f, err := os.Open(file)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	var out []manifestEntry
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		fields := strings.Fields(sc.Text())
		if len(fields) == 0 || strings.HasPrefix(fields[0], "#") {
			continue
		}
		if len(fields) != 3 {
			t.Fatalf("malformed manifest line: %q", sc.Text())
		}
		out = append(out, manifestEntry{fields[0], fields[1], fields[2]})
	}
	return out
}

var pluginRe = regexp.MustCompile(`^\s*set(?:-option)?\s+-g\s+@plugin\s+['"]([^'"#]+)['"]`)

// TestTmuxPluginsManifestMatchesConfig keeps the two lists in step. A plugin
// in .tmux.conf with no pin is never installed, so tpm silently skips it; a pin
// with no @plugin line is installed and never loaded.
func TestTmuxPluginsManifestMatchesConfig(t *testing.T) {
	root := repoRoot(t)
	conf, err := os.ReadFile(filepath.Join(root, ".tmux.conf"))
	if err != nil {
		t.Fatal(err)
	}
	var want []string
	for _, l := range lines(string(conf)) {
		if m := pluginRe.FindStringSubmatch(l); m != nil {
			want = append(want, "https://github.com/"+m[1])
		}
	}

	var got []string
	for _, e := range readManifest(t, filepath.Join(root, "scripts", "tmux-plugins.txt")) {
		got = append(got, e.url)
		// tpm looks for owner/repo under ~/.tmux/plugins/repo.
		if base := path.Base(e.url); e.dir != base {
			t.Errorf("%s is installed as %q, but tpm will look for %q", e.url, e.dir, base)
		}
		if !regexp.MustCompile(`^[0-9a-f]{40}$`).MatchString(e.commit) {
			t.Errorf("%s is pinned to %q, want a full 40-character commit", e.dir, e.commit)
		}
	}

	sort.Strings(want)
	sort.Strings(got)
	if strings.Join(got, "\n") != strings.Join(want, "\n") {
		t.Errorf("scripts/tmux-plugins.txt and the @plugin lines in .tmux.conf differ\nmanifest:\n  %s\n.tmux.conf:\n  %s",
			strings.Join(got, "\n  "), strings.Join(want, "\n  "))
	}
}

// pluginFixture is an offline stand-in for the real plugins: a copy of the
// scripts directory whose manifest points at a local git repository, so
// scripts/tmux-plugins.sh runs unchanged against it.
type pluginFixture struct {
	t        *testing.T
	root     string   // holds scripts/, as the repo root does
	upstream string   // the local "remote" repository
	commits  []string // oldest first
	home     string
}

func gitEnv() []string {
	// GIT_CONFIG_GLOBAL keeps the user's own git config out of the fixture.
	return append(os.Environ(),
		"GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_NOSYSTEM=1",
		"GIT_AUTHOR_NAME=test", "GIT_AUTHOR_EMAIL=test@example.com",
		"GIT_COMMITTER_NAME=test", "GIT_COMMITTER_EMAIL=test@example.com")
}

func git(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", append([]string{"-C", dir}, args...)...)
	cmd.Env = gitEnv()
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("git %s: %v\n%s", strings.Join(args, " "), err, out)
	}
	return strings.TrimSpace(string(out))
}

// newPluginFixture builds an upstream "fake" plugin with two commits and a
// manifest pinning the older one, so installing the newest by mistake shows.
func newPluginFixture(t *testing.T) *pluginFixture {
	t.Helper()
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git not installed")
	}
	f := &pluginFixture{t: t, root: t.TempDir(), upstream: t.TempDir(), home: t.TempDir()}

	scripts := filepath.Join(f.root, "scripts")
	if err := os.MkdirAll(scripts, 0o755); err != nil {
		t.Fatal(err)
	}
	src, err := os.ReadFile(filepath.Join(repoRoot(t), "scripts", "tmux-plugins.sh"))
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(scripts, "tmux-plugins.sh"), src, 0o755); err != nil {
		t.Fatal(err)
	}

	git(t, f.upstream, "init", "--quiet")
	// README is the same in every commit, so an edit to it survives a plain
	// git checkout; only the script's own dirty check stops that.
	if err := os.WriteFile(filepath.Join(f.upstream, "README"), []byte("unchanged\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	for i := 1; i <= 2; i++ {
		body := fmt.Sprintf("version %d\n", i)
		if err := os.WriteFile(filepath.Join(f.upstream, "fake.tmux"), []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
		git(t, f.upstream, "add", ".")
		git(t, f.upstream, "commit", "--quiet", "-m", body)
		f.commits = append(f.commits, git(t, f.upstream, "rev-parse", "HEAD"))
	}
	f.pin(f.commits[0])
	return f
}

// pin rewrites the manifest to pin the fake plugin at commit.
func (f *pluginFixture) pin(commit string) {
	f.t.Helper()
	line := fmt.Sprintf("# a comment, as in the real file\nfake  %s  %s\n", f.upstream, commit)
	if err := os.WriteFile(filepath.Join(f.root, "scripts", "tmux-plugins.txt"), []byte(line), 0o644); err != nil {
		f.t.Fatal(err)
	}
}

func (f *pluginFixture) run() (string, int) {
	f.t.Helper()
	cmd := exec.Command("/bin/sh", filepath.Join(f.root, "scripts", "tmux-plugins.sh"))
	cmd.Env = append(gitEnv(), "HOME="+f.home)
	out, err := cmd.CombinedOutput()
	if err == nil {
		return string(out), 0
	}
	var ee *exec.ExitError
	if errors.As(err, &ee) {
		return string(out), ee.ExitCode()
	}
	f.t.Fatalf("running tmux-plugins.sh: %v\n%s", err, out)
	return "", -1
}

func (f *pluginFixture) dir() string { return filepath.Join(f.home, ".tmux", "plugins", "fake") }

func (f *pluginFixture) head() string {
	f.t.Helper()
	return git(f.t, f.dir(), "rev-parse", "HEAD")
}

// assertNoTempDirs checks a failed install did not leave its work directory.
func (f *pluginFixture) assertNoTempDirs() {
	f.t.Helper()
	left, _ := filepath.Glob(filepath.Join(f.home, ".tmux", "plugins", ".*.tmp.*"))
	if len(left) > 0 {
		f.t.Errorf("temporary directories left behind: %v", left)
	}
}

// TestTmuxPluginsInstallsAtPin is the point of the script: the pinned commit,
// not whatever the default branch holds today.
func TestTmuxPluginsInstallsAtPin(t *testing.T) {
	f := newPluginFixture(t)

	out, code := f.run()
	if code != 0 {
		t.Fatalf("exited %d:\n%s", code, out)
	}
	if got := f.head(); got != f.commits[0] {
		t.Errorf("installed at %s, want the pinned %s (upstream's newest is %s)", got, f.commits[0], f.commits[1])
	}
	if !strings.Contains(out, "installed  fake @ "+f.commits[0][:7]) {
		t.Errorf("output should report the install, got:\n%s", out)
	}
	f.assertNoTempDirs()
}

// TestTmuxPluginsRerunWorksOffline checks a rerun on an installed machine is
// a no-op that needs no network: the upstream is deleted before the rerun.
func TestTmuxPluginsRerunWorksOffline(t *testing.T) {
	f := newPluginFixture(t)
	if out, code := f.run(); code != 0 {
		t.Fatalf("install exited %d:\n%s", code, out)
	}
	if err := os.RemoveAll(f.upstream); err != nil {
		t.Fatal(err)
	}

	out, code := f.run()
	if code != 0 {
		t.Fatalf("rerun exited %d:\n%s", code, out)
	}
	if !strings.Contains(out, "ok         fake") {
		t.Errorf("rerun should report the plugin as up to date, got:\n%s", out)
	}
}

// TestTmuxPluginsMovesToNewPin is the upgrade path: change the commit in the
// manifest, rerun, and the checkout follows.
func TestTmuxPluginsMovesToNewPin(t *testing.T) {
	f := newPluginFixture(t)
	if out, code := f.run(); code != 0 {
		t.Fatalf("install exited %d:\n%s", code, out)
	}

	f.pin(f.commits[1])
	out, code := f.run()
	if code != 0 {
		t.Fatalf("update exited %d:\n%s", code, out)
	}
	if got := f.head(); got != f.commits[1] {
		t.Errorf("after bumping the pin, HEAD = %s, want %s", got, f.commits[1])
	}
	if !strings.Contains(out, "updated    fake") {
		t.Errorf("output should report the update, got:\n%s", out)
	}
}

// TestTmuxPluginsRollsBackOffline checks returning to a pin already
// downloaded needs no network: the earlier commit is still in the checkout, so
// reverting a bad upgrade works even when upstream is unreachable.
func TestTmuxPluginsRollsBackOffline(t *testing.T) {
	f := newPluginFixture(t)
	if out, code := f.run(); code != 0 {
		t.Fatalf("install exited %d:\n%s", code, out)
	}
	f.pin(f.commits[1])
	if out, code := f.run(); code != 0 {
		t.Fatalf("upgrade exited %d:\n%s", code, out)
	}
	if err := os.RemoveAll(f.upstream); err != nil {
		t.Fatal(err)
	}

	f.pin(f.commits[0])
	out, code := f.run()
	if code != 0 {
		t.Fatalf("offline rollback exited %d:\n%s", code, out)
	}
	if got := f.head(); got != f.commits[0] {
		t.Errorf("after rolling back the pin, HEAD = %s, want %s", got, f.commits[0])
	}
}

// TestTmuxPluginsKeepsLocalChanges checks edits to a plugin are never
// discarded or carried silently onto another commit: the update is refused
// and both the edit and the checkout stay. Two cases, because git checkout
// itself refuses only when the edited file differs between the commits.
func TestTmuxPluginsKeepsLocalChanges(t *testing.T) {
	for _, file := range []string{"fake.tmux", "README"} {
		t.Run(file, func(t *testing.T) {
			f := newPluginFixture(t)
			if out, code := f.run(); code != 0 {
				t.Fatalf("install exited %d:\n%s", code, out)
			}
			edited := filepath.Join(f.dir(), file)
			if err := os.WriteFile(edited, []byte("local edit\n"), 0o644); err != nil {
				t.Fatal(err)
			}

			f.pin(f.commits[1])
			out, code := f.run()
			if code == 0 {
				t.Fatalf("should refuse to move an edited checkout, got 0:\n%s", out)
			}
			if !strings.Contains(out, "has local changes") {
				t.Errorf("output should say why, got:\n%s", out)
			}
			if got := readFile(t, edited); got != "local edit\n" {
				t.Errorf("local edit replaced with %q", got)
			}
			if got := f.head(); got != f.commits[0] {
				t.Errorf("HEAD moved to %s despite the refusal", got)
			}
		})
	}
}

// TestTmuxPluginsRejectsNonCheckout checks a directory the script did not
// create is left alone, not deleted and recloned.
func TestTmuxPluginsRejectsNonCheckout(t *testing.T) {
	f := newPluginFixture(t)
	if err := os.MkdirAll(f.dir(), 0o755); err != nil {
		t.Fatal(err)
	}
	mine := filepath.Join(f.dir(), "mine")
	if err := os.WriteFile(mine, []byte("keep\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	out, code := f.run()
	if code == 0 {
		t.Fatalf("should refuse a directory that is not a checkout, got 0:\n%s", out)
	}
	if !strings.Contains(out, "not a git checkout") {
		t.Errorf("output should say why, got:\n%s", out)
	}
	if got := readFile(t, mine); got != "keep\n" {
		t.Errorf("the directory's contents changed: %q", got)
	}
}

// TestTmuxPluginsFailedFetchLeavesNothing checks an install that cannot fetch
// leaves no directory behind. A half-made directory would read as installed
// on the next run and as a broken plugin to tpm.
func TestTmuxPluginsFailedFetchLeavesNothing(t *testing.T) {
	f := newPluginFixture(t)
	f.pin(strings.Repeat("0", 40)) // well-formed, but no such commit

	out, code := f.run()
	if code == 0 {
		t.Fatalf("should fail for a commit upstream lacks, got 0:\n%s", out)
	}
	if _, err := os.Lstat(f.dir()); err == nil {
		t.Errorf("a failed install left %s behind", f.dir())
	}
	f.assertNoTempDirs()
}

// TestTmuxPluginsRejectsBadPin checks a malformed pin fails as a manifest
// error. A short or branch-name pin would otherwise install whatever it
// happens to resolve to, which is the unpinned behaviour this replaces.
func TestTmuxPluginsRejectsBadPin(t *testing.T) {
	f := newPluginFixture(t)
	f.pin("master")

	out, code := f.run()
	if code == 0 {
		t.Fatalf("should reject a branch name as a pin, got 0:\n%s", out)
	}
	if !strings.Contains(out, "bad line") {
		t.Errorf("output should blame the manifest, got:\n%s", out)
	}
	if _, err := os.Lstat(f.dir()); err == nil {
		t.Error("a plugin was installed from a bad pin")
	}
}

// TestNetworkTmuxLoadsPinnedPlugins installs the real plugins from GitHub and
// starts tmux with them, which is the only way to learn that a pin is broken
// or that a plugin no longer works with this tmux. It needs the network, so
// it runs only under `make test-network`.
func TestNetworkTmuxLoadsPinnedPlugins(t *testing.T) {
	if os.Getenv("DOTFILES_NETWORK_TESTS") == "" {
		t.Skip("needs the network; run `make test-network`")
	}
	tmuxBin, err := exec.LookPath("tmux")
	if err != nil {
		t.Skip("tmux not installed")
	}
	root := repoRoot(t)
	home := stowInto(t)
	// Plugins call tmux by name. A real user started tmux from their PATH,
	// so it is always there; the hermetic env() PATH needs it added, or the
	// plugins fail with "command not found" (Homebrew's tmux is not in /bin).
	path := "PATH=" + filepath.Dir(tmuxBin) + ":/usr/bin:/bin:/usr/sbin:/sbin"

	cmd := exec.Command("/bin/sh", filepath.Join(root, "scripts", "tmux-plugins.sh"))
	cmd.Env = append(os.Environ(), "HOME="+home)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("make tmux-plugins: %v\n%s", err, out)
	}

	socket := fmt.Sprintf("dotfiles-plugins-%d", os.Getpid())
	tmux := func(args ...string) string {
		t.Helper()
		// Our own server, not the user's: -L picks a private socket, and
		// -f loads the config through the stowed link, as a real start does.
		c := exec.Command("tmux", append([]string{"-L", socket, "-f", filepath.Join(home, ".tmux.conf")}, args...)...)
		c.Env = env(home, path)
		out, err := c.CombinedOutput()
		if err != nil {
			t.Fatalf("tmux %s: %v\n%s", strings.Join(args, " "), err, out)
		}
		return string(out)
	}
	tmux("new-session", "-d", "-s", "probe", "sleep", "120")
	t.Cleanup(func() { _ = exec.Command("tmux", "-L", socket, "kill-server").Run() })

	// tpm runs the plugins in the background after the config loads, one
	// after another, so poll until both have taken effect or time runs out.
	//
	// catppuccin: tmux's default status-right has no styling at all.
	// tmux-yank: stock emacs copy-mode has no copy-pipe bindings.
	var status, keys string
	for range 100 {
		status = tmux("show-options", "-gv", "status-right")
		keys = tmux("list-keys", "-T", "copy-mode")
		if strings.Contains(status, "#[fg=") && strings.Contains(keys, "copy-pipe") {
			break
		}
		time.Sleep(100 * time.Millisecond)
	}
	if !strings.Contains(status, "#[fg=") {
		t.Errorf("status-right is unstyled, so catppuccin did not load:\n%s", status)
	}
	if !strings.Contains(keys, "copy-pipe") {
		t.Errorf("no copy-pipe bindings in copy-mode, so tmux-yank did not load:\n%s", keys)
	}
}
