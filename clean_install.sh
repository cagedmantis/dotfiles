#!/bin/bash
# Ubuntu bash script to get everything you want installed
# Work in progress!

# Update system
sudo apt-get update

# Install Sun Java 6   
sudo apt-get install sun-java6-jre sun-java6-plugin sun-java6-jdk

# Install Git
sudo apt-get install git-core git-gui git-docInstalls git-core, git-gui, and git-doc
sudo update-alternatives --config java

# email client
sudo apt-get install alpine

# install haskell
sudo apt-get install ghc6 ghc6-prof ghc6-doc

# install emacs
sudo apt-get install emacs haskell-mode

# install Latex
sudo apt-get install auctex texlive-full gedit-latex-plugin texlive-fonts-recommended latex-beamer texpower texlive-pictures texlive-latex-extra texpower-examples texlive-latex-recommended texlive-latex-base

# install imagemagick
sudo apt-get install imagemagick

# install pip
sudo apt-get install python-pip

# install easy_install
sudo apt-get install python-setuptools

# install clang
sudo apt-get install clang

# install virtualenv
sudo pip install virtualenv


#osx
brew install aspell --lang=en