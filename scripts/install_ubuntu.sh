#!/bin/bash

sudo apt-get update && \
    sudo apt-get install \
	 alpine \
	 aspell-en \
	 aspell-es \
	 build-essential \
	 bzip2 \
	 ca-certificates \
	 clang \
	 curl \
	 emacs \
	 fping \
	 git \
	 gnupg \
	 gnupg-agent \
	 gnupg2 \
	 htop \
	 jq \
	 netcat \
	 netmask \
	 python-pip \
	 python-setuptools \
	 silversearcher-ag \
	 tcpdump \
	 tmux \
	 tree \
	 unzip \
	 vim \
	 vlan \
	 xclip \
	 zip

# because latex
sudo apt-get install \
	 auctex \
	 gedit-latex-plugin \
	 info-beamer \
	 tex-common \
	 texlive-fonts-recommended \
	 texlive-full \
	 texlive-latex-base \
	 texlive-latex-extra \
	 texlive-latex-recommended \
	 texlive-pictures
