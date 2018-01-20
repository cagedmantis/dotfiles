all: 

bash_checkin:
	@echo " >> Copying bash files from file system to repository."
	@cp ~/.bashrc .
	@cp ~/.bash_profile .
	@cp ~/.bash_prompt .
	@cp ~/.bash_path .
	@cp ~/.bash_func .
	@cp ~/.bash_alias .
	@cp ~/.bash_osx .
	@cp ~/.bash_linux .

bash_checkout:
	@echo " >> Copying bash files onto file system."
	@cp ./.bashrc ~/
	@cp ./.bash_profile ~/
	@cp ./.bash_prompt ~/
	@cp ./.bash_path ~/
	@cp ./.bash_func ~/
	@cp ./.bash_alias ~/
	@cp ./.bash_osx ~/
	@cp ./.bash_linux ~/

misc_checkin:
	@echo " >> Copying files from file system to repository."
	@cp ~/.tmux.conf .
	@cp ~/.pinerc .

misc_checkout:
	@echo " >> Copying files from file system to repository."
	@cp ./.tmux.conf ~/
	@cp ./.pinerc ~/

checkin: bash_checkin misc_checkin

checkout: bash_checkout mist_checkout

check:
	shellcheck .bash*

.PHONY: all bash_checkin bash_checkout misc_checkin misc_checkout checkin checkout check
