all:

bash_checkin:
	@echo " >> Copying bash files from file system to repository."
	@cp ~/.bashrc .
	@cp ~/.bash_profile .
	@cp ~/.bash_logout .
	@cp -R ~/.config .

bash_checkout:
	@echo " >> Copying bash files onto file system."
	@cp ./.bashrc ~/
	@cp ./.bash_profile ~/
	@cp ./.bash_logout ~/
	@cp -R ./.config ~/

zsh_checkin:
	@echo " >> Copying zsh files from file system to repository."
	@cp ~/.zshrc .
	@cp ~/.zshenv .

zsh_checkout:
	@echo " >> Copying zsh files onto file system."
	@cp ./.zshrc ~/
	@cp ./.zshenv ~/

misc_checkin:
	@echo " >> Copying files from file system to repository."
	@cp ~/.tmux.conf .
	@cp ~/.pinerc .

misc_checkout:
	@echo " >> Copying files from file system to repository."
	@cp ./.tmux.conf ~/
	@cp ./.pinerc ~/

checkin: bash_checkin zsh_checkin misc_checkin

checkout: bash_checkout zsh_checkout misc_checkout

check:
	shellcheck .bash*

.PHONY: all bash_checkin bash_checkout zsh_checkin zsh_checkout misc_checkin misc_checkout checkin checkout check
