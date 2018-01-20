all: 

bash_checkin:
	echo " >> Copying bash files from file system to repository."
	cp -u ~/.bashrc .
	cp -u ~/.bash_profile .
	cp -u ~/.bash_prompt .
	cp -u ~/.bash_path .
	cp -u ~/.bash_func .
	cp -u ~/.bash_alias .
	cp -u ~/.bash_osx .
	cp -u ~/.bash_linux .

bash_checkout:
	echo " >> Copying bash files onto file system."
	cp -u ./.bashrc ~/
	cp -u ./.bash_profile ~/
	cp -u ./.bash_prompt ~/
	cp -u ./.bash_path ~/
	cp -u ./.bash_func ~/
	cp -u ./.bash_alias ~/
	cp -u ./.bash_osx ~/
	cp -u ./.bash_linux ~/

misc_checkin:
	echo " >> Copying files from file system to repository."
	cp -u ~/.tmux.conf .
	cp -u ~/.pinerc .

misc_checkout:
	echo " >> Copying files from file system to repository."
	cp -u ./.tmux.conf ~/
	cp -u ./.pinerc ~/

checkin: bash_checkin misc_checkin

checkout: bash_checkout mist_checkout

.PHONY: all bash_checkin bash_checkout misc_checkin misc_checkout checkin checkout
