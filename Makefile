# Stow flags.
#
# --no-folding is load-bearing: without it, when a target directory such as
# ~/.config/fish does not already exist, stow symlinks the *directory* rather
# than the files inside it. Fish then writes fish_variables, fish_history and
# generated completions straight into this git repo. --no-folding makes stow
# create real directories and link only the files.
STOW_FLAGS := --no-folding --target=$(HOME)

# A bare `make` prints the target list rather than silently stowing into $HOME.
.DEFAULT_GOAL := help

# ====================
# HELP
# ====================

# Self-documenting: a target is listed here iff its rule line carries a `## `
# comment, so the listing cannot drift from the file. Only the first makefile is
# scanned, and awk is held to POSIX (BSD awk on macOS, gawk on Linux).
help: ## Show this help
	@printf 'Usage: make <target>\n\nTargets:\n'
	@awk -F':[^#]*##[ 	]*' '/^[a-zA-Z0-9_.-]+:[^#]*##/ { printf "  %-12s %s\n", $$1, $$2 }' \
		$(firstword $(MAKEFILE_LIST))
	@printf '\nRun `make ci` before calling a change done.\n'

# ====================
# INSTALL
# ====================

# Fails with a readable message instead of make's "stow: No such file or
# directory". The scripts carry the same check for themselves.
REQUIRE_STOW = @command -v stow >/dev/null 2>&1 || { \
	echo "stow is not installed; see README.md, Install GNU Stow" >&2; exit 1; }

install: link tmux-plugins status ## First-time setup: link, install tmux plugins, report status

# create links in the home directory for the files in this repo.
link: ## Symlink this repo into $HOME (stow; safe, refuses on conflict)
	$(REQUIRE_STOW)
	stow $(STOW_FLAGS) .

unlink: ## Remove the symlinks `make link` created (leaves real files alone)
	$(REQUIRE_STOW)
	stow -D $(STOW_FLAGS) .

force-link: ## Like link, but first renames anything in the way to <name>.bak
	@scripts/force-link.sh

tmux-plugins: ## Install the tmux plugins at their pinned commits (network)
	@scripts/tmux-plugins.sh

# Guarded: --adopt moves $HOME's copies over the tracked files with no prompt.
# Afterwards the diff is printed, since that is the review step that matters.
adopt: ## DESTRUCTIVE: pull $HOME's copies into this repo (needs CONFIRM=1)
	@if [ "$(CONFIRM)" != 1 ]; then \
		echo "adopt overwrites this repo's files with the copies in $(HOME)." >&2; \
		echo "Rerun as: make adopt CONFIRM=1   (then review with git diff)" >&2; \
		exit 1; \
	fi
	$(REQUIRE_STOW)
	stow --adopt $(STOW_FLAGS) .
	@git --no-pager diff --stat

status: ## Has `make link` run on this machine? (read-only)
	@scripts/status.sh

# ====================
# CHECKS
# ====================

# lint  -- Layer 1: parse and lint every config file. Fast; run it on save.
# test  -- Layer 2: behavioural tests. Installs the configs into a throwaway
#          $HOME and runs real shells against them, which is where the
#          fresh-machine bugs actually show up.
# ci    -- both, in the order that fails fastest.
# test-network -- installs the real tmux plugins from GitHub and loads them.
#          Kept out of ci so ci stays offline and hermetic.

lint: ## Layer 1: parse + shellcheck every config file (fast)
	@scripts/lint.sh

test: ## Layer 2: behavioural tests against a throwaway $HOME
	@cd tests && go test ./...

test-v: ## Layer 2, verbose
	@cd tests && go test -v ./...

ci: lint test ## lint then test, failing fast

test-network: ## Tests that need the network: pinned tmux plugins load
	@cd tests && DOTFILES_NETWORK_TESTS=1 go test -count=1 -run Network ./...

.PHONY: help install link unlink force-link tmux-plugins adopt status lint test test-v ci test-network
