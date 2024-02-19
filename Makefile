
# create links in the home directory for the files in this repo.
link:
	stow --target=$(HOME) .

adopt:
	stow --adopt --target=$(HOME) .
