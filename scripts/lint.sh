#!/bin/sh
# Layer 1 static analysis: parse and lint every configuration file.
#
# Fast enough to run on every save. It catches syntax errors and, via
# shellcheck, whole classes of quoting and portability bugs -- but it cannot
# catch ordering or runtime behaviour (compinit before fpath, PATH duplication
# across nested shells). Those are what the Go tests in tests/ are for.
#
# Missing tools are reported and skipped rather than failing the run, so this
# stays useful on a machine that has not installed shellcheck yet. Anything
# actually broken exits non-zero.

set -u

cd "$(dirname "$0")/.." || exit 1

status=0
skipped=''

have() { command -v "$1" >/dev/null 2>&1; }
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; status=1; }
skip() { printf '  skip  %s (%s not installed)\n' "$1" "$2"; skipped="$skipped $2"; }

echo "== shellcheck =="
if have shellcheck; then
	# SC1090/SC1091 are "can't follow non-constant source". Dotfiles source
	# paths that only exist at runtime by design, so these are excluded
	# globally rather than annotated at two dozen call sites.
	for f in .bashrc .bash_profile .bash_logout; do
		[ -f "$f" ] || continue
		if shellcheck --shell=bash --exclude=SC1090,SC1091 "$f"; then ok "$f"; else bad "$f"; fi
	done
	if shellcheck --shell=sh --exclude=SC1090,SC1091 .profile; then ok ".profile"; else bad ".profile"; fi
	if shellcheck --shell=sh scripts/lint.sh; then ok "scripts/lint.sh"; else bad "scripts/lint.sh"; fi
else
	skip "bash and sh files" shellcheck
fi

echo "== zsh parse =="
# zsh has no shellcheck equivalent; -n parses without executing. Note this will
# not catch the compinit/fpath ordering bug -- see tests/ for that.
if have zsh; then
	for f in .zshrc .zshenv; do
		if zsh -n "$f"; then ok "$f"; else bad "$f"; fi
	done
else
	skip "zsh files" zsh
fi

echo "== fish parse =="
if have fish; then
	if fish --no-execute .config/fish/config.fish; then ok "config.fish"; else bad "config.fish"; fi
else
	skip "config.fish" fish
fi

echo "== tmux parse =="
if have tmux; then
	sock="dotfiles-lint-$$"
	# A session running `sleep` keeps the server alive long enough to query;
	# `new-session -d true` exits immediately and takes the server with it.
	if tmux -f .tmux.conf -L "$sock" new-session -d 'sleep 30' 2>&1; then
		ok ".tmux.conf"
		tmux -L "$sock" kill-server 2>/dev/null
	else
		bad ".tmux.conf"
	fi
else
	skip ".tmux.conf" tmux
fi

echo "== stow dry run =="
if have stow; then
	target="${TMPDIR:-/tmp}/dotfiles-lint-$$"
	mkdir -p "$target"
	# HOME is overridden so stow cannot find a previously installed
	# ~/.stow-global-ignore: this must behave like a brand new machine.
	if out=$(HOME="$target" stow --no --verbose=2 --no-folding --target="$target" . 2>&1); then
		if printf '%s\n' "$out" | grep -E '^LINK:' \
			| grep -qE 'history|DS_Store|Makefile|README|TODO|CLAUDE|\.claude|\.git|stow-|tests|scripts'; then
			printf '%s\n' "$out" | grep -E '^LINK:' | sed 's/^/    /'
			bad "stow would link files that belong only in the repo"
		else
			ok "stow links only real dotfiles"
		fi
	else
		printf '%s\n' "$out" | sed 's/^/    /'
		bad "stow dry run"
	fi
	rm -rf "$target"
else
	skip "stow dry run" stow
fi

echo
if [ -n "$skipped" ]; then
	printf 'Skipped checks need:%s\n' "$skipped"
fi
if [ "$status" -eq 0 ]; then
	echo "lint: OK"
else
	echo "lint: FAILED"
fi
exit "$status"
