#!/bin/bash
# Install my Ubuntu essentials.

# Update system
sudo apt-get update

# Install Sun Java 6   
# sudo apt-get install sun-java6-jre sun-java6-plugin sun-java6-jdk

# Install Git
sudo apt-get install git-core git-gui git-docInstalls git-core, git-gui, and git-doc

# Install Java
# sudo update-alternatives --config java

# Install Alpine
sudo apt-get install alpine

# Install Haskell
sudo apt-get install ghc6 ghc6-prof ghc6-doc

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

# Install Go
sudo apt-get install golang
