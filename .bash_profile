#!/bin/bash

# ~/.bash_profile
# Carlos Amedee

echo "bash_profile"

# Set Path
export PATH="$PATH:/usr/local/sbin"
export PATH="$PATH:$HOME/bin"
export PATH="$PATH:$HOME/code/go/bin"
export PATH="$PATH:/usr/local/Cellar/ruby/1.9.3-p194/bin"
export PATH="$PATH:/anaconda/bin"

# Set Gopath
export GOPATH=$HOME/code/go

if [ -f ~/.bashrc ]; then
    source "$HOME/.bashrc"
fi

if [ -f ~/.bash_profile_ps ]; then
    source "$HOME/.bash_profile_ps"
fi

if [ -f ~/.bash_profile_do ]; then
    source "$HOME/.bash_profile_do"
fi

# set some OS specific definitions
case $MACHTYPE in
    *redhat*)
        echo "Rehat box"
    ;;
    *linux*)
        echo "Linux box"
    ;;
    *darwin*)
        echo "OS X box"
    ;;
    *cygwin*)
        echo "Windows box"
    ;;
    *)
    ;;
esac

# MacPorts Installer addition on 2012-08-09_at_23:34:39: adding an appropriate PATH variable for use with MacPorts.
export PATH=/opt/local/bin:/opt/local/sbin:$PATH
# Finished adapting your PATH environment variable for use with MacPorts.

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

if [ -f ~/.git-completion.bash ]; then
  . ~/.git-completion.bash
fi

# hack for osx agent change in Sierra
{ eval `ssh-agent`; ssh-add -K; } &>/dev/null


# docker
VM=vmdev
DOCKER_MACHINE=/usr/local/bin/docker-machine

VBOXMANAGE=/Applications/VirtualBox.app/Contents/MacOS/VBoxManage

BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

unset DYLD_LIBRARY_PATH
unset LD_LIBRARY_PATH

VM_STATUS=$($DOCKER_MACHINE status $VM 2>&1)
if [ "$VM_STATUS" != "Running" ]; then
	$DOCKER_MACHINE start $VM
	yes | $DOCKER_MACHINE regenerate-certs $VM
fi

eval $($DOCKER_MACHINE env --shell=bash $VM)

