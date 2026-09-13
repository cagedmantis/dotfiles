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
