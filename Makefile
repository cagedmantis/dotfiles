# Stow flags.
#
# --no-folding is load-bearing: without it, when a target directory such as
# ~/.config/fish does not already exist, stow symlinks the *directory* rather
# than the files inside it. Fish then writes fish_variables, fish_history and
# generated completions straight into this git repo. --no-folding makes stow
# create real directories and link only the files.
STOW_FLAGS := --no-folding --target=$(HOME)

# create links in the home directory for the files in this repo.
link:
	stow $(STOW_FLAGS) .

adopt:
	stow --adopt $(STOW_FLAGS) .

# ====================
# CHECKS
# ====================

# lint  -- Layer 1: parse and lint every config file. Fast; run it on save.
# test  -- Layer 2: behavioural tests. Installs the configs into a throwaway
#          $HOME and runs real shells against them, which is where the
#          fresh-machine bugs actually show up.
# ci    -- both, in the order that fails fastest.

lint:
	@scripts/lint.sh

test:
	@cd tests && go test ./...

test-v:
	@cd tests && go test -v ./...

ci: lint test

.PHONY: link adopt lint test test-v ci
