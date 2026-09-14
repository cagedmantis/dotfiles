package dotfiles_test

import (
	"fmt"
	"regexp"
	"sort"
	"strings"
	"testing"
)

// noConfigArgs runs a shell with its configuration suppressed, giving a
// baseline of names the shell defines on its own.
var noConfigArgs = map[string][]string{
	"bash": {"--norc", "--noprofile", "-ic"},
	"zsh":  {"--no-rcs", "-ic"},
	"fish": {"--no-config", "-c"},
}

// internalNames are implementation details rather than commands anyone types.
// They are excluded from the parity comparison entirely.
var internalNames = map[string]bool{
	// Prompt helpers. Each shell names these differently -- bash
	// parse_git_branch, zsh git_prompt_info, fish _git_prompt_info -- which is
	// itself drift, tracked under "Prompt implementation" in TODO.md. Only fish
	// uses the underscore convention that would have filtered them
	// automatically.
	"parse_git_branch": true, "parse_jj_info": true, "parse_vcs_info": true,
	"git_prompt_info": true, "jj_prompt_info": true, "vcs_prompt_info": true,

	// POSIX PATH helpers from .profile. fish has no equivalent because
	// fish_add_path is a builtin that is already idempotent.
	"path_append": true, "path_prepend": true,

	// bash's version-probing shopt wrapper.
	"shopt_enable": true,

	// zsh's completion system, pulled in by `autoload -Uz compinit`. These
	// belong to zsh, not to this repository, but a --no-rcs baseline does not
	// load compinit so they look config-defined.
	"compaudit": true, "compdef": true, "compdump": true,
	"compinit": true, "compinstall": true, "getent": true, "zrecompile": true,

	// fish machinery that appears once a config is loaded.
	"fish_sigtrap_handler": true, "fish_prompt": true, "fish_mode_prompt": true,
}

// knownDivergence records commands that intentionally exist in some shells but
// not others. Anything not listed must resolve in all three, so drift surfaces
// as a failure rather than as a surprise months later. The value is the reason,
// kept here because this is where someone will be standing when it fails.
var knownDivergence = map[string]string{
	"docker-create-f": "bash only; docker-machine was deprecated in 2021 and its vmwarefusion/virtualbox drivers do not work on Apple Silicon (TODO #39 removes these)",
	"docker-create-v": "bash only; same as docker-create-f",
	"emacs":           "bash only; a macOS-specific alias to the GUI Emacs.app bundle, which has no meaning on Linux or under fish",
	"screen":          "bash only; legacy TERM wrapper kept for the rare screen session",
	"vboxmanage":      "bash only; macOS path to the VirtualBox bundle",
	"gitBranchPush":   "bash only; the long-form name behind the gbp alias. gbp itself is the interface and is present in all three shells",
}

// configuredNames returns the alias and function names this repository adds to
// the given shell, by subtracting a no-config baseline.
//
// Subtraction alone is not a sufficient parity test: fish ships its own ls, ll,
// la and grep functions, so a config that *overrides* them adds nothing new and
// would look like a missing alias. It is used only to discover candidate names;
// parity is then judged by whether each name actually resolves.
func configuredNames(t *testing.T, s shell, home string) map[string]bool {
	t.Helper()
	args, ok := noConfigArgs[s.name]
	if !ok {
		t.Skipf("no baseline invocation defined for %s", s.name)
	}

	withCfg, _ := runShell(t, s, home, s.printNames)
	base := s
	base.loginArgs = func(script string) []string { return append(append([]string(nil), args...), script) }
	withoutCfg, _ := runShell(t, base, home, s.printNames)

	baseline := map[string]bool{}
	for _, n := range lines(withoutCfg) {
		baseline[n] = true
	}
	out := map[string]bool{}
	for _, n := range lines(withCfg) {
		if baseline[n] || strings.HasPrefix(n, "_") || internalNames[n] {
			continue
		}
		out[n] = true
	}
	return out
}

// kind classifies how a name resolves in a shell. Existence alone is not
// enough: `gs` is an alias for `git status` here, but ghostscript also ships a
// /usr/bin/gs, so `command -v gs` succeeds even when the alias is gone. A
// parity check built on existence silently misses that, which is exactly what
// happened the first time this test was written.
type kind string

const (
	kindShell    kind = "shell"    // alias, function or abbreviation: defined by config
	kindExternal kind = "external" // a binary or builtin that happens to share the name
	kindMissing  kind = "missing"
)

func classify(raw string) kind {
	switch strings.TrimSpace(raw) {
	case "alias", "function", "abbreviation":
		return kindShell
	case "", "none":
		return kindMissing
	default: // file, builtin, command, reserved, keyword
		return kindExternal
	}
}

// resolveKinds reports how each candidate name resolves in the given shell.
func resolveKinds(t *testing.T, s shell, home string, names []string) map[string]kind {
	t.Helper()

	var script string
	switch s.name {
	case "bash":
		script = `for n in $CANDIDATES; do k=$(type -t "$n" 2>/dev/null); printf '%s %s\n' "$n" "${k:-none}"; done`
	case "zsh":
		// ${=VAR} forces sh-style splitting; zsh does not split unquoted
		// parameters, so a plain `for n in $CANDIDATES` loops once over the
		// whole string.
		script = `for n in ${=CANDIDATES}; do k=$(whence -w "$n" 2>/dev/null); printf '%s %s\n' "$n" "${${k#*: }:-none}"; done`
	case "fish":
		script = `for n in (string split " " -- $CANDIDATES)
			if abbr --query $n
				printf '%s abbreviation\n' $n
			else
				set -l k (type -t $n 2>/dev/null)
				printf '%s %s\n' $n (test -n "$k"; and echo $k; or echo none)
			end
		end`
	default:
		t.Skipf("no classifier for %s", s.name)
	}

	out, _ := runShell(t, s, home, script, "CANDIDATES="+strings.Join(names, " "))
	got := map[string]kind{}
	for _, l := range lines(out) {
		if f := strings.Fields(l); len(f) == 2 {
			got[f[0]] = classify(f[1])
		}
	}
	return got
}

// TestAliasParity asserts the user-facing command set stays in sync across
// bash, zsh and fish. TODO's parity matrix found kubectl completion, nvm, rvm
// and virtualenvwrapper in bash only, and the git shortcuts implemented three
// different ways; this keeps new drift visible.
func TestAliasParity(t *testing.T) {
	home := sandbox(t)

	var tested []shell
	candidates := map[string]bool{}
	for _, s := range shells {
		if s.name == "sh" {
			continue // sh has no interactive configuration
		}
		if _, err := lookShell(s); err != nil {
			continue
		}
		tested = append(tested, s)
		for n := range configuredNames(t, s, home) {
			candidates[n] = true
		}
	}
	if len(tested) < 2 {
		t.Skip("need at least two shells installed to compare")
	}

	names := sortedKeys(candidates)
	if len(names) == 0 {
		t.Fatal("discovered no configured command names; the extraction is broken")
	}
	t.Logf("comparing %d command names across %d shells", len(names), len(tested))

	byShell := map[string]map[string]kind{}
	for _, s := range tested {
		byShell[s.name] = resolveKinds(t, s, home, names)
	}

	var drift []string
	for _, name := range names {
		// A name the configuration defines in one shell must be defined in all
		// of them. Resolving to an unrelated binary of the same name does not
		// count -- that is the gs/ghostscript trap.
		var wrong []string
		for _, s := range tested {
			if byShell[s.name][name] != kindShell {
				wrong = append(wrong, fmt.Sprintf("%s(%s)", s.name, byShell[s.name][name]))
			}
		}
		if len(wrong) == 0 {
			continue
		}
		sort.Strings(wrong)
		if reason, ok := knownDivergence[name]; ok {
			t.Logf("known divergence: %q is %v -- %s", name, wrong, reason)
			continue
		}
		drift = append(drift, name+" not shell-defined in "+strings.Join(wrong, ","))
	}

	if len(drift) > 0 {
		t.Errorf("shell command sets have drifted (%d names):\n  %s\n\n"+
			"Either define the name in the missing shells, or add it to knownDivergence with a reason.",
			len(drift), strings.Join(drift, "\n  "))
	}
}

func sortedKeys(m map[string]bool) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

// TestListAliasesMatchPlatform guards TODO #16. `-G` means "colour" on BSD ls
// but "suppress the group column" on GNU coreutils, so the listing aliases must
// choose their flags per platform. zsh hardcoded -G for every shell, and fish
// probed correctly for `ls` but still hardcoded -G in la/l/ll.
//
// This also covers a case TestAliasParity structurally cannot: fish ships its
// own ls, la and ll functions, so deleting our overrides leaves the names
// resolving as functions and looks identical to a kind-based check. Asserting
// on the flags distinguishes fish's default `ls -lh` from our `ls -alhFG`.
func TestListAliasesMatchPlatform(t *testing.T) {
	home := sandbox(t)

	// dircolors ships with GNU coreutils and not with BSD userland, which makes
	// it the same probe the configuration itself uses.
	gnu := false
	if out, _ := runShell(t, shells[0], home, `command -v dircolors >/dev/null 2>&1 && echo gnu || echo bsd`); strings.TrimSpace(out) == "gnu" {
		gnu = true
	}
	// BSD: a flag cluster ending in G, e.g. -alhFG. GNU: an explicit --color.
	want := regexp.MustCompile(`-[a-zA-Z]*G\b`)
	label := "a BSD -...G flag cluster"
	if gnu {
		want = regexp.MustCompile(`--color=auto`)
		label = "--color=auto"
	}
	t.Logf("platform looks %s; expecting %s", map[bool]string{true: "GNU", false: "BSD"}[gnu], label)

	for _, s := range shells {
		if s.name == "sh" {
			continue
		}
		for _, name := range []string{"ls", "l", "la", "ll"} {
			t.Run(s.name+"/"+name, func(t *testing.T) {
				query := "alias " + name
				if s.name == "fish" {
					query = "functions " + name
				}
				out, _ := runShell(t, s, home, query)
				if strings.TrimSpace(out) == "" {
					t.Fatalf("%s is not defined in %s", name, s.name)
				}
				if !want.MatchString(out) {
					t.Errorf("%s %s does not use %s for this platform:\n  %s",
						s.name, name, label, strings.TrimSpace(out))
				}
			})
		}
	}
}
