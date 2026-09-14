// Package dotfiles_test exercises the shell configuration in the repository
// root by installing it into a pristine, throwaway $HOME and observing how real
// shells behave with it.
//
// The sandbox is the whole point. Every P0 bug these tests guard against was
// invisible on a machine that already had the configuration installed, and only
// appeared on a fresh one: PATH entries inherited from a parent shell masked
// missing ones, and a previously stowed ~/.stow-global-ignore masked a broken
// ignore list. So each test starts from an empty directory, stows the real
// configuration into it exactly as `make link` would, and runs shells with a
// hand-built environment rather than the ambient one.
package dotfiles_test

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"testing"
	"time"
)

// repoRoot is the directory holding the dotfiles: the parent of tests/.
func repoRoot(t *testing.T) string {
	t.Helper()
	abs, err := filepath.Abs("..")
	if err != nil {
		t.Fatalf("resolving repo root: %v", err)
	}
	if _, err := os.Stat(filepath.Join(abs, ".stow-local-ignore")); err != nil {
		t.Fatalf("repo root %s does not look like the dotfiles repo: %v", abs, err)
	}
	return abs
}

// sandboxOnce builds the pristine $HOME a single time per test binary. Stowing
// is pure filesystem work and the shells only read from it, so sharing is safe
// and keeps a full run to one stow invocation instead of one per test.
var (
	sandboxOnce sync.Once
	sandboxHome string
	sandboxErr  error
)

// sandbox returns a $HOME with the repository stowed into it, exactly as
// `make link` would install it on a new machine.
func sandbox(t *testing.T) string {
	t.Helper()
	sandboxOnce.Do(func() {
		root := repoRoot(t)
		dir, err := os.MkdirTemp("", "dotfiles-home-")
		if err != nil {
			sandboxErr = err
			return
		}
		sandboxHome = dir

		// path_append/path_prepend are existence-checked by design, so a
		// genuinely empty $HOME would legitimately produce a PATH without
		// ~/bin. Create the directories a real machine would have, so the
		// tests below assert on the ordering and dedup logic rather than
		// re-discovering that the guards work.
		for _, d := range homeDirs {
			if err := os.MkdirAll(filepath.Join(dir, d), 0o755); err != nil {
				sandboxErr = err
				return
			}
		}

		cmd := exec.Command("stow", "--no-folding", "--target="+dir, ".")
		cmd.Dir = root
		// HOME matters here: stow consults $HOME/.stow-global-ignore, and the
		// point of this sandbox is that no such file exists.
		cmd.Env = append(os.Environ(), "HOME="+dir)
		if out, err := cmd.CombinedOutput(); err != nil {
			sandboxErr = &exitError{err: err, out: string(out)}
		}
	})
	if sandboxErr != nil {
		t.Fatalf("building sandbox: %v", sandboxErr)
	}
	return sandboxHome
}

type exitError struct {
	err error
	out string
}

func (e *exitError) Error() string { return e.err.Error() + ": " + e.out }

// homeDirs are the $HOME-relative directories the configuration is expected to
// put on PATH. They must exist for the existence-checked helpers to add them.
var homeDirs = []string{"bin", "go/bin", ".local/bin"}

// shell describes one shell under test and how to ask it for its PATH.
type shell struct {
	name string
	// lookup names to try, in order; the first one found on the system wins.
	bins []string
	// loginArgs runs a script through a login+interactive shell.
	loginArgs func(script string) []string
	// printPath emits one PATH entry per line.
	printPath string
	// printAliases emits one alias/function/abbreviation name per line.
	printNames string
}

var shells = []shell{
	{
		name: "sh",
		bins: []string{"/bin/sh"},
		// sh has no interactive rc file, so -l alone is the relevant mode.
		loginArgs:  func(s string) []string { return []string{"-lc", s} },
		printPath:  `printf '%s\n' "$PATH" | tr : '\n'`,
		printNames: `alias 2>/dev/null | sed 's/=.*//'`,
	},
	{
		name:       "bash",
		bins:       []string{"/bin/bash", "bash"},
		loginArgs:  func(s string) []string { return []string{"-lic", s} },
		printPath:  `printf '%s\n' "$PATH" | tr : '\n'`,
		printNames: `{ alias | sed -E "s/^alias ([^=]+)=.*/\1/"; declare -F | sed 's/^declare -f //'; }`,
	},
	{
		name:       "zsh",
		bins:       []string{"/bin/zsh", "zsh"},
		loginArgs:  func(s string) []string { return []string{"-lic", s} },
		printPath:  `print -l $path`,
		printNames: `{ print -l ${(k)aliases}; print -l ${(k)functions}; }`,
	},
	{
		name:       "fish",
		bins:       []string{"fish", "/opt/homebrew/bin/fish", "/usr/local/bin/fish", "/usr/bin/fish"},
		loginArgs:  func(s string) []string { return []string{"-lic", s} },
		printPath:  `for p in $PATH; echo $p; end`,
		printNames: `begin; functions -n; abbr --list; end`,
	},
}

// bin resolves the shell's executable, skipping the test when absent so the
// suite still runs on a machine that lacks, say, fish.
func (s shell) bin(t *testing.T) string {
	t.Helper()
	for _, b := range s.bins {
		if strings.HasPrefix(b, "/") {
			if _, err := os.Stat(b); err == nil {
				return b
			}
			continue
		}
		if p, err := exec.LookPath(b); err == nil {
			return p
		}
	}
	t.Skipf("%s not installed", s.name)
	return ""
}

// lookShell resolves a shell's executable without failing the test, for
// callers that need to skip a missing shell rather than abort.
func lookShell(s shell) (string, error) {
	var err error
	for _, b := range s.bins {
		if strings.HasPrefix(b, "/") {
			if _, statErr := os.Stat(b); statErr == nil {
				return b, nil
			}
			continue
		}
		var p string
		if p, err = exec.LookPath(b); err == nil {
			return p, nil
		}
	}
	if err == nil {
		err = os.ErrNotExist
	}
	return "", err
}

// env builds the hermetic environment every shell runs under.
func env(home string, extra ...string) []string {
	e := []string{
		"HOME=" + home,
		// Deliberately minimal: anything the configuration needs on PATH it
		// must put there itself. This is what makes missing entries visible.
		"PATH=/usr/bin:/bin:/usr/sbin:/sbin",
		// TERM=dumb doubles as the assertion subject for TestTermNotOverridden.
		"TERM=dumb",
		// Short-circuits the ssh-agent block in .bashrc. These tests are not
		// about agent spawning, and starting one per shell would be slow and
		// would fail anyway on macOS, where a long $HOME pushes the agent
		// socket past the ~104 character sun_path limit.
		"SSH_AUTH_SOCK=/dev/null",
		"LANG=C",
		// Present in every real login environment. tmux's default-command is
		// set to "${SHELL}", which silently expands to nothing -- and so does
		// nothing at all -- if this is missing.
		"SHELL=/bin/zsh",
	}
	return append(e, extra...)
}

// runShell executes script in the shell and returns stdout and stderr.
func runShell(t *testing.T, s shell, home, script string, extraEnv ...string) (string, string) {
	t.Helper()
	cmd := exec.Command(s.bin(t), s.loginArgs(script)...)
	cmd.Env = env(home, extraEnv...)
	cmd.Dir = home
	var stdout, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	done := make(chan error, 1)
	if err := cmd.Start(); err != nil {
		t.Fatalf("%s: start: %v", s.name, err)
	}
	go func() { done <- cmd.Wait() }()
	select {
	case <-done:
	case <-time.After(30 * time.Second):
		_ = cmd.Process.Kill()
		t.Fatalf("%s: timed out after 30s running %q", s.name, script)
	}
	return stdout.String(), stderr.String()
}

// runShellArgs is runShell with explicit argv, for tests that need a mode other
// than the default login+interactive one.
func runShellArgs(t *testing.T, s shell, home string, args []string, extraEnv ...string) (string, string) {
	t.Helper()
	alt := s
	alt.loginArgs = func(string) []string { return args }
	return runShell(t, alt, home, "", extraEnv...)
}

// lines splits output into non-empty trimmed lines.
func lines(s string) []string {
	var out []string
	for _, l := range strings.Split(s, "\n") {
		if l = strings.TrimSpace(l); l != "" {
			out = append(out, l)
		}
	}
	return out
}

// benignStderr matches output that comes from running a shell without a
// controlling terminal rather than from the configuration under test.
var benignStderr = []string{
	"no job control in this shell",
	"can't access tty",
	"Inappropriate ioctl for device",
}

func filterBenign(s string) []string {
	var out []string
	for _, l := range lines(s) {
		benign := false
		for _, b := range benignStderr {
			if strings.Contains(l, b) {
				benign = true
				break
			}
		}
		if !benign {
			out = append(out, l)
		}
	}
	return out
}

func isDarwin() bool { return runtime.GOOS == "darwin" }
