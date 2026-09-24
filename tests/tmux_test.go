package dotfiles_test

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// tmuxServer starts a tmux server on a private socket using the repository's
// .tmux.conf, and returns a function for querying it.
//
// $HOME points at the sandbox, which deliberately has no ~/.tmux/plugins/tpm.
// That isolates the configuration's own settings from anything tpm would load,
// which is what these assertions are about. The plugins-present counterpart is
// TestNetworkTmuxLoadsPinnedPlugins, which needs the network and so runs only
// under `make test-network`.
func tmuxServer(t *testing.T) func(args ...string) string {
	t.Helper()
	if _, err := exec.LookPath("tmux"); err != nil {
		t.Skip("tmux not installed")
	}
	root := repoRoot(t)
	home := sandbox(t)
	socket := fmt.Sprintf("dotfiles-test-%d", os.Getpid())

	run := func(args ...string) (string, error) {
		full := append([]string{"-f", filepath.Join(root, ".tmux.conf"), "-L", socket}, args...)
		cmd := exec.Command("tmux", full...)
		cmd.Env = env(home)
		out, err := cmd.CombinedOutput()
		return strings.TrimSpace(string(out)), err
	}

	if out, err := run("new-session", "-d", "-s", "probe", "sleep", "120"); err != nil {
		t.Fatalf("starting tmux with .tmux.conf: %v\n%s", err, out)
	}
	t.Cleanup(func() { _, _ = run("kill-server") })

	return func(args ...string) string {
		out, err := run(args...)
		if err != nil {
			t.Fatalf("tmux %s: %v\n%s", strings.Join(args, " "), err, out)
		}
		return out
	}
}

// TestTmuxConfigLoads is the most basic guard: a syntax error or an option that
// this tmux version rejects makes every new session print an error.
func TestTmuxConfigLoads(t *testing.T) {
	q := tmuxServer(t)
	if got := q("display-message", "-p", "#{session_name}"); got != "probe" {
		t.Errorf("session name = %q, want %q", got, "probe")
	}
}

// TestTmuxOptions asserts the settings the configuration explicitly makes are
// the ones actually in effect.
func TestTmuxOptions(t *testing.T) {
	q := tmuxServer(t)
	for _, c := range []struct{ option, want string }{
		{"prefix", "C-g"},          // deliberately not C-b, for Emacs users
		{"base-index", "1"},        // windows start at 1, not 0
		{"renumber-windows", "on"}, // no gaps after closing a window
		{"mouse", "on"},
		{"default-terminal", "tmux-256color"}, // defeated if a shell exports TERM
		{"escape-time", "10"},                 // low, so Esc is not laggy in editors
		{"history-limit", "50000"},
		{"status-keys", "emacs"},
		{"focus-events", "on"},
		{"display-time", "4000"},
		{"mode-keys", "emacs"},         // explicit, so $EDITOR cannot flip it to vi
		{"set-clipboard", "external"},  // forwards our copies; "on" would also trust panes
		{"allow-rename", "off"},        // programs must not rename windows via escapes
		{"detach-on-destroy", "off"},   // stay attached when a session's last window closes
		{"display-panes-time", "2000"}, // one second is too short to read
	} {
		t.Run(c.option, func(t *testing.T) {
			got := q("show-options", "-gv", c.option)
			if got != c.want {
				t.Errorf("tmux option %s = %q, want %q", c.option, got, c.want)
			}
		})
	}
}

// TestTmuxWindowOptions covers the per-window settings, which live in a
// separate option table and are easy to set on the wrong one.
func TestTmuxWindowOptions(t *testing.T) {
	q := tmuxServer(t)
	for _, c := range []struct{ option, want string }{
		{"pane-base-index", "1"},
		{"aggressive-resize", "on"},
		{"monitor-activity", "on"},
		{"automatic-rename", "on"},
	} {
		t.Run(c.option, func(t *testing.T) {
			got := q("show-options", "-gwv", c.option)
			if got != c.want {
				t.Errorf("tmux window option %s = %q, want %q", c.option, got, c.want)
			}
		})
	}
}

// TestTmuxKeyBindings guards the bindings the configuration adds, including the
// splits that preserve the current directory -- an easy thing to lose silently
// when reorganising the file.
func TestTmuxKeyBindings(t *testing.T) {
	q := tmuxServer(t)
	binds := q("list-keys", "-T", "prefix")

	for _, c := range []struct{ key, want string }{
		{"|", "split-window -h"},
		{"-", "split-window -v"},
		{"h", "select-pane -L"},
		{"j", "select-pane -D"},
		{"k", "select-pane -U"},
		{"l", "select-pane -R"},
		{"r", "source-file"},
	} {
		t.Run("key_"+c.key, func(t *testing.T) {
			var found bool
			for _, line := range lines(binds) {
				// list-keys quotes some keys; match on the command instead of
				// trying to reproduce tmux's quoting rules.
				if strings.Contains(line, c.want) && bindsKey(line, c.key) {
					found = true
					break
				}
			}
			if !found {
				t.Errorf("no prefix binding for %q running %q", c.key, c.want)
			}
		})
	}

	// The splits must inherit the current directory; without -c the new pane
	// opens in whatever directory the session started in.
	for _, key := range []string{"|", "-"} {
		if !strings.Contains(binds, "pane_current_path") {
			t.Errorf("split binding %q does not preserve #{pane_current_path}", key)
		}
	}
}

// bindsKey reports whether a `tmux list-keys` line binds the given key.
func bindsKey(line, key string) bool {
	f := strings.Fields(line)
	for i, tok := range f {
		if tok != "-T" || i+2 >= len(f) {
			continue
		}
		got := strings.Trim(f[i+2], `"'`)
		return got == key
	}
	return false
}

// TestTmuxDefaultCommand guards TODO #29. On macOS tmux otherwise starts a
// login shell per pane, which re-runs path_helper and reorders PATH on every
// split.
func TestTmuxDefaultCommand(t *testing.T) {
	q := tmuxServer(t)
	got := q("show-options", "-gv", "default-command")
	if got == "" {
		t.Error("default-command is unset; panes will start login shells and re-run path_helper")
	}
}

// TestTmuxStatusBarLeftToPlugin guards TODO #24. The config used to define a
// full status bar that the catppuccin plugin then silently overwrote. The
// config must not set status-left/status-right, so there is exactly one owner.
func TestTmuxStatusBarLeftToPlugin(t *testing.T) {
	root := repoRoot(t)
	b, err := os.ReadFile(filepath.Join(root, ".tmux.conf"))
	if err != nil {
		t.Fatal(err)
	}
	for _, opt := range []string{"status-left ", "status-right ", "window-status-format ", "window-status-current-format "} {
		for _, line := range lines(string(b)) {
			if strings.HasPrefix(strings.TrimSpace(line), "set") && strings.Contains(line, opt) {
				t.Errorf("%s.tmux.conf sets %q, which the catppuccin plugin overwrites: %s", "", opt, line)
			}
		}
	}
}

// TestTmuxSensibleNotLoaded guards TODO #26. tmux-sensible set escape-time,
// history-limit, status-keys and more, and because tpm runs last its opinions
// landed on top of the explicit settings above rather than deferring to them.
func TestTmuxSensibleNotLoaded(t *testing.T) {
	root := repoRoot(t)
	b, err := os.ReadFile(filepath.Join(root, ".tmux.conf"))
	if err != nil {
		t.Fatal(err)
	}
	for _, line := range lines(string(b)) {
		l := strings.TrimSpace(line)
		if strings.HasPrefix(l, "set") && strings.Contains(l, "tmux-sensible") {
			t.Errorf("tmux-sensible is loaded again; it overrides the explicit settings above it: %s", l)
		}
	}
}
