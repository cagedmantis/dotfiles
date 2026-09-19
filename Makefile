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
	@awk -F':[^#]*##[ 	]*' '/^[a-zA-Z0-9_.-]+:[^#]*##/ { printf "  %-8s %s\n", $$1, $$2 }' \
		$(firstword $(MAKEFILE_LIST))
	@printf '\nRun `make ci` before calling a change done.\n'

# ====================
# INSTALL
# ====================

# create links in the home directory for the files in this repo.
link: ## Symlink this repo into $HOME (stow; safe, refuses on conflict)
	stow $(STOW_FLAGS) .

adopt: ## DESTRUCTIVE: pull $HOME's copies into this repo, overwriting it
	stow --adopt $(STOW_FLAGS) .

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

lint: ## Layer 1: parse + shellcheck every config file (fast)
	@scripts/lint.sh

test: ## Layer 2: behavioural tests against a throwaway $HOME
	@cd tests && go test ./...

test-v: ## Layer 2, verbose
	@cd tests && go test -v ./...

ci: lint test ## lint then test, failing fast

.PHONY: help link adopt status lint test test-v ci
