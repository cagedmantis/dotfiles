#!/bin/bash

sudo apt-get update && \
    sudo apt-get install \
		 alpine \
		 apt-transport-https \
		 aspell-en \
		 aspell-es \
		 build-essential \
		 bzip2 \
		 ca-certificates \
		 ca-certificates \
		 clang \
		 curl \
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
		 software-properties-common \
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

# Docker
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository \
	 "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

sudo apt-get update && \
	sudo apt-get install docker-ce


sudo apt-get install qemu-kvm libvirt-bin ubuntu-vm-builder bridge-utils virt-manager
