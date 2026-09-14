package dotfiles_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// TestPathContainsExpectedDirs guards TODO #12 and #13: fish had neither ~/bin
// nor ~/go/bin, and .profile contributed nothing at all, so `sh -l` and every
// fish shell were missing directories the other shells had.
func TestPathContainsExpectedDirs(t *testing.T) {
	home := sandbox(t)
	for _, s := range shells {
		t.Run(s.name, func(t *testing.T) {
			got, _ := runShell(t, s, home, s.printPath)
			have := map[string]bool{}
			for _, p := range lines(got) {
				have[p] = true
			}
			for _, d := range homeDirs {
				want := filepath.Join(home, d)
				if !have[want] {
					t.Errorf("PATH missing %s\ngot:\n  %s", want, strings.Join(lines(got), "\n  "))
				}
			}
		})
	}
}

// TestPathHasNoDuplicates guards TODO #10. PATH used to be appended to
// unconditionally by files that run on every shell invocation, so each level of
// nesting doubled it -- zsh reached 40 entries at depth three.
func TestPathHasNoDuplicates(t *testing.T) {
	home := sandbox(t)
	for _, s := range shells {
		t.Run(s.name, func(t *testing.T) {
			got, _ := runShell(t, s, home, s.printPath)
			seen := map[string]int{}
			for _, p := range lines(got) {
				seen[p]++
			}
			for p, n := range seen {
				if n > 1 {
					t.Errorf("PATH contains %s %d times", p, n)
				}
			}
		})
	}
}

// TestPathStableWhenNested guards TODO #10 in the shape it actually had:
// unconditional PATH appends in files that run on every shell invocation, so
// each level of nesting doubled PATH. Nesting is the normal case under tmux,
// make, or an editor's terminal.
//
// Two details matter, both learned the hard way.
//
// First, the shells must be NON-login. On macOS, /usr/libexec/path_helper runs
// for every login shell and rebuilds PATH from /etc/paths, deduplicating as it
// goes -- so a nested login shell silently repairs the very bug this test
// exists to catch. Measured against a deliberately broken config, login nesting
// reported a flat 17/17 entries while non-login nesting reported 7/8/9.
//
// Second, the query lives in files rather than in interpolated command strings.
// Go's %q is not shell quoting, so a `$path` embedded that way is expanded by
// the outer shell and the result word-splits on any PATH entry with a space.
func TestPathStableWhenNested(t *testing.T) {
	home := sandbox(t)
	for _, s := range shells {
		if s.name == "sh" {
			continue // no rc file is read for a non-login sh, nothing to re-run
		}
		t.Run(s.name, func(t *testing.T) {
			bin := s.bin(t)
			dir := t.TempDir()
			probe := filepath.Join(dir, "probe")
			nest := filepath.Join(dir, "nest")
			deep := filepath.Join(dir, "deep")

			// Each file re-enters the shell one more level. Writing them out
			// avoids any nested quoting: every $VAR below is expanded by the
			// shell that finally reads the file, not by an outer one.
			write := func(path, body string) {
				if err := os.WriteFile(path, []byte(body+"\n"), 0o644); err != nil {
					t.Fatal(err)
				}
			}
			write(probe, s.printPath)
			write(nest, `"$SHBIN" -ic 'source "$PROBE"'`)
			write(deep, `"$SHBIN" -ic 'source "$NEST"'`)

			vars := []string{"SHBIN=" + bin, "PROBE=" + probe, "NEST=" + nest}
			depth := make([][]string, 3)
			for i, f := range []string{probe, nest, deep} {
				out, stderr := runShellArgs(t, s, home, []string{"-ic", `source "$` + map[int]string{0: "PROBE", 1: "NEST", 2: "DEEP"}[i] + `"`},
					append(vars, "DEEP="+deep)...)
				_ = f
				depth[i] = lines(out)
				if len(depth[i]) == 0 {
					t.Fatalf("depth %d produced no PATH entries; the probe is broken, not the config.\nstderr:\n%s", i+1, stderr)
				}
			}

			t.Logf("entries by depth: %d, %d, %d", len(depth[0]), len(depth[1]), len(depth[2]))
			for i := 1; i < len(depth); i++ {
				if len(depth[i]) != len(depth[0]) {
					t.Errorf("PATH grew with nesting: depth 1 had %d entries, depth %d had %d\ndepth %d:\n  %s",
						len(depth[0]), i+1, len(depth[i]), i+1, strings.Join(depth[i], "\n  "))
				}
			}
		})
	}
}

// TestNoStderrOnStartup guards TODO #4 and #8: an unguarded `. ~/.cargo/env`
// and a bash-4-only `shopt -s dirspell` each printed an error on every single
// interactive start.
func TestNoStderrOnStartup(t *testing.T) {
	home := sandbox(t)
	for _, s := range shells {
		t.Run(s.name, func(t *testing.T) {
			_, stderr := runShell(t, s, home, "true")
			if noise := filterBenign(stderr); len(noise) > 0 {
				t.Errorf("startup wrote to stderr:\n  %s", strings.Join(noise, "\n  "))
			}
		})
	}
}

// TestTermNotOverridden guards TODO #14. Exporting TERM from an rc file
// clobbers whatever the terminal emulator set, which defeated tmux's
// tmux-256color and broke TRAMP and `ssh host cmd`, both of which use dumb.
func TestTermNotOverridden(t *testing.T) {
	home := sandbox(t)
	for _, s := range shells {
		t.Run(s.name, func(t *testing.T) {
			got, _ := runShell(t, s, home, `printf '%s\n' "$TERM"`)
			if g := strings.TrimSpace(got); g != "dumb" {
				t.Errorf("TERM = %q, want %q (the shell must not set TERM)", g, "dumb")
			}
		})
	}
}

// TestEditorIsConsistent guards TODO #18, where EDITOR was set twice to two
// different values and the one non-interactive tools actually saw pointed at an
// absolute Homebrew path that does not exist on Linux.
func TestEditorIsConsistent(t *testing.T) {
	home := sandbox(t)
	seen := map[string]string{}
	for _, s := range shells {
		t.Run(s.name, func(t *testing.T) {
			got, _ := runShell(t, s, home, `printf '%s\n' "$EDITOR"`)
			ed := strings.TrimSpace(got)
			if ed == "" {
				t.Fatal("EDITOR is empty")
			}
			if strings.Contains(ed, "/opt/homebrew") || strings.Contains(ed, "/Users/") {
				t.Errorf("EDITOR = %q hardcodes a machine-specific path", ed)
			}
			seen[s.name] = ed
		})
	}
	var first, firstName string
	for name, ed := range seen {
		if first == "" {
			first, firstName = ed, name
			continue
		}
		if ed != first {
			t.Errorf("EDITOR differs between shells: %s=%q, %s=%q", firstName, first, name, ed)
		}
	}
}

// TestAlternateEditorStartsDaemon guards the emacsclient fallback: the empty
// string is a documented special case meaning "start the daemon and reconnect",
// and it must be set-but-empty rather than unset for that to trigger.
func TestAlternateEditorStartsDaemon(t *testing.T) {
	home := sandbox(t)
	for _, s := range shells {
		t.Run(s.name, func(t *testing.T) {
			script := `if [ "${ALTERNATE_EDITOR+set}" = set ]; then printf 'set:[%s]\n' "$ALTERNATE_EDITOR"; else printf 'unset\n'; fi`
			if s.name == "fish" {
				script = `if set -q ALTERNATE_EDITOR; printf 'set:[%s]\n' "$ALTERNATE_EDITOR"; else; printf 'unset\n'; end`
			}
			got, _ := runShell(t, s, home, script)
			if g := strings.TrimSpace(got); g != "set:[]" {
				t.Errorf("ALTERNATE_EDITOR is %s, want set-but-empty so emacsclient starts the daemon", g)
			}
		})
	}
}

// TestNonInteractivePathMatches guards TODO #11. PATH used to be built in
// .bashrc and .zshrc, which run only for interactive shells, so `ssh host cmd`,
// cron and make subshells saw a different PATH from the terminal.
func TestNonInteractivePathMatches(t *testing.T) {
	home := sandbox(t)
	cases := []struct {
		name        string
		s           shell
		nonInteract []string
	}{
		{"bash", shells[1], []string{"-lc", shells[1].printPath}},
		{"zsh", shells[2], []string{"-c", shells[2].printPath}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			interactive, _ := runShell(t, c.s, home, c.s.printPath)
			ni := c.s
			ni.loginArgs = func(string) []string { return c.nonInteract }
			nonInteractive, _ := runShell(t, ni, home, "")
			for _, d := range homeDirs {
				want := filepath.Join(home, d)
				if !strings.Contains(nonInteractive, want) {
					t.Errorf("non-interactive PATH missing %s\ninteractive:\n  %s\nnon-interactive:\n  %s",
						want, strings.Join(lines(interactive), "\n  "), strings.Join(lines(nonInteractive), "\n  "))
				}
			}
		})
	}
}

// TestStartupTime is a regression guard, not a benchmark. The budget is
// deliberately loose: it exists to catch someone adding a network call or an
// unconditional `brew --prefix` to an rc file, not to police milliseconds.
func TestStartupTime(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping timing test in -short mode")
	}
	const budget = 1500 * time.Millisecond
	home := sandbox(t)
	for _, s := range shells {
		t.Run(s.name, func(t *testing.T) {
			best := time.Hour
			for i := 0; i < 3; i++ { // best of three; the first run pays for cold caches
				start := time.Now()
				runShell(t, s, home, "true")
				if d := time.Since(start); d < best {
					best = d
				}
			}
			if best > budget {
				t.Errorf("startup took %v, budget %v", best.Round(time.Millisecond), budget)
			}
			t.Logf("%s startup: %v", s.name, best.Round(time.Millisecond))
		})
	}
}

// TestFishInteractiveGuard guards the parity item that fish had no
// `status is-interactive` guard, so every `fish -c script` built the prompt and
// defined every alias and abbreviation.
func TestFishInteractiveGuard(t *testing.T) {
	home := sandbox(t)
	var fish shell
	for _, s := range shells {
		if s.name == "fish" {
			fish = s
		}
	}
	if _, err := lookShell(fish); err != nil {
		t.Skip("fish not installed")
	}

	// Key on our distinctive flag cluster, not on the name and not on "--color".
	// fish ships its own ls and ll: its ls body mentions both -G and
	// --color=auto, and its ll is `ls -lh`. Ours is `ls -alhF...` on either
	// platform, so "alhF" identifies our override specifically.
	const ours = "alhF"

	nonInteractive, _ := runShellArgs(t, fish, home, []string{"-c", "functions ll 2>/dev/null; true"})
	if strings.Contains(nonInteractive, ours) {
		t.Error("fish defines our ll alias in a non-interactive shell; the status is-interactive guard is not working")
	}

	interactive, _ := runShellArgs(t, fish, home, []string{"-ic", "functions ll 2>/dev/null; true"})
	if !strings.Contains(interactive, ours) {
		t.Errorf("fish does not define our ll alias in an interactive shell; the guard is too broad.\ngot: %s", interactive)
	}

	// Commands usable from scripts must stay outside the guard.
	for _, fn := range []string{"gbp", "chromekill"} {
		out, _ := runShellArgs(t, fish, home, []string{"-c", "functions -q " + fn + "; and echo yes"})
		if strings.TrimSpace(out) != "yes" {
			t.Errorf("%s is not available to non-interactive fish; it is a command, not an interactive alias", fn)
		}
	}
}

// TestLocalOverrideHook guards the parity item that only bash had a hook for
// machine-specific settings, and that it had four of them.
func TestLocalOverrideHook(t *testing.T) {
	home := sandbox(t)
	cases := []struct{ shellName, file, script string }{
		{"bash", ".shell_local", `printf '%s\n' "$DOTFILES_LOCAL_MARKER"`},
		{"zsh", ".shell_local", `printf '%s\n' "$DOTFILES_LOCAL_MARKER"`},
		{"fish", ".config/fish/local.fish", `printf '%s\n' "$DOTFILES_LOCAL_MARKER"`},
	}
	for _, c := range cases {
		t.Run(c.shellName, func(t *testing.T) {
			var s shell
			for _, sh := range shells {
				if sh.name == c.shellName {
					s = sh
				}
			}
			if _, err := lookShell(s); err != nil {
				t.Skip(c.shellName + " not installed")
			}
			path := filepath.Join(home, c.file)
			body := "export DOTFILES_LOCAL_MARKER=hooked\n"
			if c.shellName == "fish" {
				body = "set -gx DOTFILES_LOCAL_MARKER hooked\n"
			}
			if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
				t.Fatal(err)
			}
			defer os.Remove(path)

			got, _ := runShell(t, s, home, c.script)
			if strings.TrimSpace(got) != "hooked" {
				t.Errorf("%s did not source %s (marker = %q)", c.shellName, c.file, strings.TrimSpace(got))
			}
		})
	}
}

// TestNoUntrustedSourceDirs guards TODO #43. The gcloud probe put whatever it
// found on PATH and then *sourced* that directory's completion.*.inc from every
// shell, which is arbitrary code execution from the probed location. One of the
// probed locations was $HOME/Downloads -- a browser's default target, where a
// single drive-by download of a directory with the right name would have been
// enough.
//
// This asserts on the configuration text rather than on runtime behaviour,
// because the point is that the path must never be probed, not merely that
// nothing hostile happens to be there today.
func TestNoUntrustedSourceDirs(t *testing.T) {
	root := repoRoot(t)
	untrusted := []string{"Downloads", "Desktop", "/tmp/", "/var/tmp/"}

	for _, name := range []string{".profile", ".bashrc", ".zshrc", ".zshenv", ".bash_profile", ".config/fish/config.fish"} {
		b, err := os.ReadFile(filepath.Join(root, name))
		if err != nil {
			continue
		}
		for i, line := range strings.Split(string(b), "\n") {
			code := strings.TrimSpace(line)
			// Comments may name these paths to explain why they are excluded.
			if code == "" || strings.HasPrefix(code, "#") {
				continue
			}
			for _, bad := range untrusted {
				if strings.Contains(code, bad) {
					t.Errorf("%s:%d references the untrusted directory %q in executable code: %s",
						name, i+1, bad, code)
				}
			}
		}
	}
}

// TestGcloudProbeSkipsDownloads is the runtime companion. It plants two
// candidate SDKs in the sandbox -- one at a legitimate install location and one
// under Downloads -- and asserts the probe picks the install location and
// ignores the download directory entirely.
//
// Written this way rather than reading $GCLOUD_SDK_ROOT from the ambient
// environment, which would skip on any machine without gcloud and so guard
// nothing.
func TestGcloudProbeSkipsDownloads(t *testing.T) {
	home := sandbox(t)

	good := filepath.Join(home, "google-cloud-sdk")
	bad := filepath.Join(home, "Downloads", "google-cloud-sdk")
	for _, d := range []string{good, bad} {
		if err := os.MkdirAll(filepath.Join(d, "bin"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	defer func() {
		os.RemoveAll(good)
		os.RemoveAll(filepath.Join(home, "Downloads"))
	}()

	for _, s := range shells {
		t.Run(s.name, func(t *testing.T) {
			out, _ := runShell(t, s, home, `printf '%s\n' "$GCLOUD_SDK_ROOT"`)
			got := strings.TrimSpace(out)
			if got != good {
				t.Errorf("GCLOUD_SDK_ROOT = %q, want %q", got, good)
			}
			if strings.Contains(got, "Downloads") {
				t.Errorf("probe selected a download directory: %q. Its completion script is sourced by every shell.", got)
			}
		})
	}

	// The Downloads copy must not reach PATH either.
	for _, s := range shells {
		out, _ := runShell(t, s, home, s.printPath)
		for _, p := range lines(out) {
			if strings.Contains(p, "Downloads") {
				t.Errorf("%s put %q on PATH", s.name, p)
			}
		}
	}

	// With the legitimate SDK removed, the Downloads copy is the only candidate
	// left. The probe must still find nothing.
	//
	// This case matters: with both present the install location wins on probe
	// order alone, so re-adding Downloads to the list would not change the
	// result and the assertions above would pass a reintroduced bug.
	os.RemoveAll(good)
	for _, s := range shells {
		t.Run("only-downloads/"+s.name, func(t *testing.T) {
			out, _ := runShell(t, s, home, `printf '%s\n' "$GCLOUD_SDK_ROOT"`)
			if got := strings.TrimSpace(out); got != "" {
				t.Errorf("probe selected %q with only a Downloads candidate present; it must find nothing", got)
			}
		})
	}
}
