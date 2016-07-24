#!/bin/bash
# Install my Ubuntu essentials.

# Update system
sudo apt-get update

# Install Git
sudo apt-get install git

# Install Alpine
sudo apt-get install alpine

# Install Haskell
sudo apt-get install ghc

# Install emacs
sudo apt-get install emacs

# Install Latex
sudo apt-get install auctex texlive-full gedit-latex-plugin texlive-fonts-recommended latex-beamer texpower texlive-pictures texlive-latex-extra texpower-examples texlive-latex-recommended texlive-latex-base

# Install imagemagick
sudo apt-get install imagemagick

# Install pip
sudo apt-get install python-pip

# Install easy_install
sudo apt-get install python-setuptools

# Install clang
sudo apt-get install clang

# Install virtualenv
sudo pip install virtualenv

# Install mit scheme
sudo apt-get install mit-scheme

# Network tools
sudo apt-get install vlan netcat fping tcpdump netmask

# Tmux
sudo apt-get install tmux

# Install Go
export GOFILE=go1.6.3.linux-amd64.tar.gz
export GOLANG_SHA=cdde5e08530c0579255d6153b08fdb3b8e47caabbe717bc7bcd7561275a87aeb

curl -o /tmp/$GOFILE https://storage.googleapis.com/golang/$GOFILE
echo "$GOLANG_SHA" > /tmp/$GOFILE.sha256
shasum -a 256 /tmp/$GOFILE | shasum -c /tmp/$GOFILE.sha256
sudo tar -C /usr/local -xzf $gofilename
rm /tmp/$GOFILE /tmp/$GOFILE.sha256

