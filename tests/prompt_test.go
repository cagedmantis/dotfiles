package dotfiles_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
	"time"
)

// promptFuncs is the function each shell's prompt calls for its VCS fragment.
var promptFuncs = map[string]string{
	"bash": "parse_vcs_info",
	"zsh":  "vcs_prompt_info",
	"fish": "_vcs_prompt_info",
}

func shellNamed(name string) shell {
	for _, s := range shells {
		if s.name == name {
			return s
		}
	}
	panic("no shell " + name)
}

// colourRe matches the colour markup the prompts wrap around their text:
// ANSI SGR and fish's "(B" reset, and zsh's %F{n}/%f prompt escapes.
var colourRe = regexp.MustCompile(`\x1b\[[0-9;]*m|\x1b\(B|%F\{[0-9]+\}|%f`)

var fragmentRe = regexp.MustCompile(`<([^<>]*)>`)

// vcsPrompt returns the VCS fragment shell s renders in dir, without colour:
// "(main+)", "(feat@kxyzwvut*)", or "" outside a repository.
func vcsPrompt(t *testing.T, s shell, home, dir string, extraEnv ...string) string {
	t.Helper()
	fn := promptFuncs[s.name]
	script := `cd '` + dir + `' && printf '<%s>' "$(` + fn + `)"`
	if s.name == "fish" {
		script = `cd '` + dir + `'; and printf '<%s>' (` + fn + `)`
	}
	out, stderr := runShell(t, s, home, script, extraEnv...)
	m := fragmentRe.FindAllStringSubmatch(colourRe.ReplaceAllString(out, ""), -1)
	if m == nil {
		t.Fatalf("%s: no prompt fragment in output %q (stderr %q)", s.name, out, stderr)
	}
	return strings.TrimSpace(m[len(m)-1][1])
}

// promptShells runs f once per installed shell that has a VCS prompt.
func promptShells(t *testing.T, f func(t *testing.T, s shell)) {
	for _, name := range []string{"bash", "zsh", "fish"} {
		s := shellNamed(name)
		t.Run(name, func(t *testing.T) {
			if _, err := lookShell(s); err != nil {
				t.Skip(name + " not installed")
			}
			f(t, s)
		})
	}
}

// run executes a fixture-building command and returns its trimmed stdout.
func run(t *testing.T, dir string, env []string, name string, args ...string) string {
	t.Helper()
	cmd := exec.Command(name, args...)
	cmd.Dir = dir
	cmd.Env = env
	var stderr strings.Builder
	cmd.Stderr = &stderr
	out, err := cmd.Output()
	if err != nil {
		t.Fatalf("%s %s: %v\n%s", name, strings.Join(args, " "), err, stderr.String())
	}
	return strings.TrimSpace(string(out))
}

// fixtureEnv keeps fixture commands away from the user's own git and jj
// configuration, which could otherwise change what the fixtures contain.
func fixtureEnv(t *testing.T) []string {
	home := t.TempDir()
	empty := filepath.Join(home, "empty.toml")
	if err := os.WriteFile(empty, nil, 0o644); err != nil {
		t.Fatal(err)
	}
	return []string{
		"PATH=" + os.Getenv("PATH"),
		"HOME=" + home,
		"GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_NOSYSTEM=1",
		"GIT_AUTHOR_NAME=t", "GIT_AUTHOR_EMAIL=t@example.com",
		"GIT_COMMITTER_NAME=t", "GIT_COMMITTER_EMAIL=t@example.com",
		"JJ_CONFIG=" + empty, "JJ_USER=t", "JJ_EMAIL=t@example.com",
	}
}

func write(t *testing.T, path, content string) {
	t.Helper()
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

// homeWithJJ returns a throwaway $HOME whose ~/.local/bin/jj is the jj
// installed on this machine, skipping the test when there is none. jj has to
// be reached through a directory .profile puts on PATH itself: a PATH passed
// in from here does not survive a login shell on Debian, whose /etc/profile
// resets it.
func homeWithJJ(t *testing.T) string {
	t.Helper()
	bin, err := exec.LookPath("jj")
	if err != nil {
		t.Skip("jj not installed")
	}
	home := stowInto(t)
	if err := os.Symlink(bin, filepath.Join(home, ".local", "bin", "jj")); err != nil {
		t.Fatal(err)
	}
	return home
}

// homeWithBrokenJJ returns a throwaway $HOME whose jj always fails, standing
// in for a jj too old for the prompt's template, or broken. ~/.local/bin is
// first on PATH, so it shadows any jj installed system-wide.
func homeWithBrokenJJ(t *testing.T) string {
	t.Helper()
	home := stowInto(t)
	if err := os.WriteFile(filepath.Join(home, ".local", "bin", "jj"), []byte("#!/bin/sh\nexit 1\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	return home
}

// TestGitPrompt pins the git fragment's markers -- + staged, * unstaged,
// ? untracked -- and the @sha form for a detached HEAD, in every shell.
func TestGitPrompt(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git not installed")
	}
	home := sandbox(t)
	env := fixtureEnv(t)
	repo := t.TempDir()
	git := func(args ...string) string { return run(t, repo, env, "git", args...) }
	git("init", "-q", "-b", "main")
	write(t, filepath.Join(repo, "a"), "1\n")
	git("add", "a")
	git("commit", "-q", "-m", "one")
	sha := git("rev-parse", "--short=7", "HEAD")

	steps := []struct {
		name  string
		apply func()
		want  string
	}{
		{"clean", func() {}, "(main)"},
		{"untracked", func() { write(t, filepath.Join(repo, "u"), "") }, "(main?)"},
		{"unstaged", func() { write(t, filepath.Join(repo, "a"), "2\n") }, "(main*?)"},
		{"staged", func() { git("add", "a") }, "(main+?)"},
		{"staged and unstaged", func() { write(t, filepath.Join(repo, "a"), "3\n") }, "(main+*?)"},
		{"detached", func() { git("checkout", "-q", "--detach") }, "(@" + sha + "+*?)"},
	}
	for _, st := range steps {
		st.apply()
		t.Run(st.name, func(t *testing.T) {
			promptShells(t, func(t *testing.T, s shell) {
				if got := vcsPrompt(t, s, home, repo); got != st.want {
					t.Errorf("prompt = %q, want %q", got, st.want)
				}
			})
		})
	}

	t.Run("outside a repo", func(t *testing.T) {
		promptShells(t, func(t *testing.T, s shell) {
			if got := vcsPrompt(t, s, home, t.TempDir()); got != "" {
				t.Errorf("prompt = %q outside any repository, want nothing", got)
			}
		})
	})
}

// TestJJPrompt pins the jj fragment: bookmark@change, with * for a non-empty
// working copy and ! for a conflict, in every shell.
func TestJJPrompt(t *testing.T) {
	home := homeWithJJ(t)
	env := fixtureEnv(t)
	// --no-colocate: a pure jj repo, so a failing jj prompt cannot be masked
	// by the git fallback. (jj 0.47 colocates by default.)
	repo := filepath.Join(t.TempDir(), "r")
	run(t, filepath.Dir(repo), env, "jj", "git", "init", "--no-colocate", repo)
	jj := func(args ...string) string { return run(t, repo, env, "jj", args...) }
	change := func() string {
		return jj("--ignore-working-copy", "log", "--no-graph", "-r", "@", "-T", "change_id.shortest(8)")
	}

	steps := []struct {
		name  string
		apply func()
		want  func() string
	}{
		{"fresh", func() {}, func() string { return "(@" + change() + ")" }},
		{"non-empty", func() {
			write(t, filepath.Join(repo, "f"), "1\n")
			jj("status") // snapshot: the prompt itself never does
		}, func() string { return "(@" + change() + "*)" }},
		{"bookmark on an ancestor", func() {
			jj("commit", "-m", "one")
			jj("bookmark", "create", "feat", "-r", "@-")
		}, func() string { return "(feat@" + change() + ")" }},
		{"conflict", func() {
			jj("new", "feat", "-m", "a")
			write(t, filepath.Join(repo, "f"), "a\n")
			a := change()
			jj("new", "feat", "-m", "b")
			write(t, filepath.Join(repo, "f"), "b\n")
			b := change()
			jj("new", a, b) // snapshots b first, then merges the two edits of f
		}, func() string { return "(feat@" + change() + "!)" }},
	}
	for _, st := range steps {
		st.apply()
		want := st.want()
		t.Run(st.name, func(t *testing.T) {
			promptShells(t, func(t *testing.T, s shell) {
				if got := vcsPrompt(t, s, home, repo); got != want {
					t.Errorf("prompt = %q, want %q", got, want)
				}
			})
		})
	}
}

// TestJJPromptFallback guards the colocated-repo fallback: when jj is missing
// or fails, a repo with .git beside .jj shows the git prompt instead of
// nothing -- but a pure jj repo inside some other git repo must not borrow
// that enclosing repo's prompt.
func TestJJPromptFallback(t *testing.T) {
	if _, err := exec.LookPath("git"); err != nil {
		t.Skip("git not installed")
	}
	home := homeWithBrokenJJ(t)
	env := fixtureEnv(t)

	// Colocated, built with git alone: the prompt only looks for .jj, so an
	// empty one is enough to make it try jj first.
	colo := t.TempDir()
	run(t, colo, env, "git", "init", "-q", "-b", "main")
	write(t, filepath.Join(colo, "a"), "1\n")
	run(t, colo, env, "git", "add", "a")
	run(t, colo, env, "git", "commit", "-q", "-m", "one")
	if err := os.Mkdir(filepath.Join(colo, ".jj"), 0o755); err != nil {
		t.Fatal(err)
	}
	write(t, filepath.Join(colo, ".git", "info", "exclude"), ".jj\n")

	// A pure jj repo nested in a git repo: no .git of its own.
	outer := t.TempDir()
	run(t, outer, env, "git", "init", "-q", "-b", "outer")
	nested := filepath.Join(outer, "nested")
	if err := os.MkdirAll(filepath.Join(nested, ".jj"), 0o755); err != nil {
		t.Fatal(err)
	}

	promptShells(t, func(t *testing.T, s shell) {
		if got := vcsPrompt(t, s, home, colo); got != "(main)" {
			t.Errorf("colocated repo with failing jj: prompt = %q, want the git prompt %q", got, "(main)")
		}
		if got := vcsPrompt(t, s, home, nested); got != "" {
			t.Errorf("pure jj repo inside a git repo, failing jj: prompt = %q, want nothing", got)
		}
	})
}

// TestJJPromptSkipsLegacyRepoConfig guards the hardening for pre-0.38 repo
// config. jj 0.38+ still reads a plain-file .jj/repo/config.toml, moves it
// under ~/.config/jj/repos/ and trusts it from then on, so a prompt that ran
// jj in a repo you only cd'd into would adopt that repo's config for you. The
// prompt must leave the file alone and fall back to git.
func TestJJPromptSkipsLegacyRepoConfig(t *testing.T) {
	home := homeWithJJ(t)
	broken := homeWithBrokenJJ(t)
	env := fixtureEnv(t)
	repo := t.TempDir()
	run(t, repo, env, "git", "init", "-q", "-b", "main")
	run(t, repo, env, "jj", "git", "init", "--colocate")
	legacy := filepath.Join(repo, ".jj", "repo", "config.toml")
	write(t, legacy, "[ui]\ncolor = \"always\"\n")

	promptShells(t, func(t *testing.T, s shell) {
		// What the git fallback renders here, whatever HEAD state jj left.
		want := vcsPrompt(t, s, broken, repo)
		if got := vcsPrompt(t, s, home, repo); got != want {
			t.Errorf("prompt = %q, want the git fallback %q: it ran jj on a repo with legacy config", got, want)
		}
		if fi, err := os.Lstat(legacy); err != nil || fi.Mode()&os.ModeSymlink != 0 {
			t.Errorf("legacy repo config was migrated by the prompt (err=%v)", err)
		}
	})
}

// TestJJPromptPinsSigning guards the jj hardening flags. With
// DOTFILES_JJ_SNAPSHOT=1 the prompt's jj snapshots the working copy, which
// writes a commit, and a config with signing.behavior=force runs
// signing.backends.gpg.program to sign it -- arbitrary code per prompt render.
func TestJJPromptPinsSigning(t *testing.T) {
	home := homeWithJJ(t)
	env := fixtureEnv(t)
	repo := filepath.Join(t.TempDir(), "r")
	run(t, filepath.Dir(repo), env, "jj", "git", "init", "--no-colocate", repo)

	dir := t.TempDir()
	marker := filepath.Join(dir, "ran")
	evil := filepath.Join(dir, "evil")
	if err := os.WriteFile(evil, []byte("#!/bin/sh\ntouch '"+marker+"'\nexit 1\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	cfg := filepath.Join(dir, "config.toml")
	write(t, cfg, "[signing]\nbehavior = \"force\"\nbackend = \"gpg\"\nbackends.gpg.program = \""+evil+"\"\n")

	promptShells(t, func(t *testing.T, s shell) {
		write(t, filepath.Join(repo, "f"), s.name) // new content to snapshot
		got := vcsPrompt(t, s, home, repo, "DOTFILES_JJ_SNAPSHOT=1", "JJ_CONFIG="+cfg)
		if _, err := os.Stat(marker); err == nil {
			t.Fatal("the prompt ran the configured signing program")
		}
		if !strings.HasSuffix(got, "*)") {
			t.Errorf("prompt = %q, want a snapshotted, non-empty working copy (ending \"*)\")", got)
		}
	})
}

// TestJJCompletion checks every shell registers jj's completion when jj is
// installed, caches the generated script, and regenerates the cache only once
// the jj binary is newer than it.
func TestJJCompletion(t *testing.T) {
	home := homeWithJJ(t)
	checks := map[string]string{
		"bash": `complete -p jj 2>/dev/null | grep -q _clap_complete_jj && echo registered`,
		"zsh":  `[[ ${_comps[jj]} == _clap_dynamic_completer_jj ]] && echo registered`,
		"fish": `complete -c jj | string match -q -- '*COMPLETE=fish*'; and echo registered`,
	}
	promptShells(t, func(t *testing.T, s shell) {
		cacheHome := t.TempDir()
		cache := filepath.Join(cacheHome, "dotfiles", "jj-completion."+s.name)
		xdg := "XDG_CACHE_HOME=" + cacheHome

		out, _ := runShell(t, s, home, checks[s.name], xdg)
		if !strings.Contains(out, "registered") {
			t.Fatalf("jj completion is not registered; got %q", out)
		}
		if fi, err := os.Stat(cache); err != nil || fi.Size() == 0 {
			t.Fatalf("no cached completion script at %s (err=%v)", cache, err)
		}

		// A cache newer than the binary is used as-is.
		write(t, cache, "# sentinel\n")
		future := time.Now().Add(time.Hour)
		if err := os.Chtimes(cache, future, future); err != nil {
			t.Fatal(err)
		}
		runShell(t, s, home, "true", xdg)
		if b, _ := os.ReadFile(cache); string(b) != "# sentinel\n" {
			t.Error("cache was regenerated although it is newer than jj")
		}

		// A cache older than the binary is regenerated.
		past := time.Unix(0, 0)
		if err := os.Chtimes(cache, past, past); err != nil {
			t.Fatal(err)
		}
		runShell(t, s, home, "true", xdg)
		if b, _ := os.ReadFile(cache); !strings.Contains(string(b), "COMPLETE") {
			t.Error("cache older than jj was not regenerated")
		}
	})
}
