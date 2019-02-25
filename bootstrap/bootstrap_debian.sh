#!/usr/bin/env bash

# Install my Ubuntu essentials.

# Update system
sudo apt-get update

# Install essentials
sudo apt-get install \
	 alpine \
	 build-essential \
	 clang \
	 emacs \
	 fping \
	 ghc \
	 git \
	 imagemagick \
	 mit-scheme \
	 mosh \
	 netcat \
	 netmask \
	 python-pip \
	 python-setuptools \
	 tcpdump \
	 tmux \
	 vlan

# Install Latex
sudo apt-get install \
	 auctex \
	 texlive-full \
	 gedit-latex-plugin \
	 texlive-fonts-recommended \
	 latex-beamer \
	 texpower \
	 texlive-pictures \
	 texlive-latex-extra \
	 texpower-examples \
	 texlive-latex-recommended \
	 texlive-latex-base

# Install virtualenv
sudo pip install virtualenv
