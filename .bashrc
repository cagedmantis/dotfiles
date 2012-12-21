# ~/.bashrc
# Carlos Amedee

# Paths
PATH=$PATH:$HOME/bin

export CLASSPATH=

export CLOJURE_EXT=$HOME/.clojure

# Android tools
if [ -d $HOME/bin/android-sdk-linux_86/tools ]; then
    export PATH=${PATH}:$HOME/bin/android-sdk-linux_86/tools:$HOME/bin
fi

# System settings
export TERM="xterm-color"
export DISPLAY=:0.0
export EDITOR=emacs
export BROWSER=google-chrome
export GREP_OPTIONS='--color=auto'
export GREP_COLOR='1;31'
export HISTSIZE=10000
export SAVEHIST=10000

# shopt settings
# needs a check for shopt

# append to the history file
shopt -s histappend

# check the size of the window
shopt -s checkwinsize

# auto correct spelling errors
shopt -s cdspell

# "." files included in expansion
shopt -s dotglob

# multiline commands
shopt -s cmdhist

# If window size changes, redraw contents
shopt -s checkwinsize

# Prompt
export PS1="\[\033[01;32m\]\u\[\033[01;34m\]@\[\033[01;32m\]\h\[\033[00m\]: \[\e[0;33m\]\w\[\033[00m\]\n$ "

# Aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias l='ls -lah' 
    alias la='ls -AF' 
    alias ll='ls -lFh' 
    alias grep='grep --color=auto' 
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
else
    alias la='ls -A'
    alias l='ls -lah' 
    alias la='ls -AF' 
    alias ll='ls -lFh' 
fi

alias rdesktop='rdesktop -g 1024x800'
alias ping='ping -c 5'
alias df='df -h' 
alias du='du -h -c' 
alias screen='TERM=screen screen'
alias recent="ls -lAt | head"
alias back='cd $OLDPWD'
alias openports='sudo lsof -i -P | grep -i "listen"'

case $MACHTYPE in
    *redhat*)
        ## Redhat/Centos/Fedora
        alias yum='sudo yum'
        alias tree='tree -Ca -I ".git|*.pyc|*.swp"'
    ;;
    *linux*)
        ## Debian/Ubuntu
        alias apt-get='sudo apt-get'
        alias apt-cache='sudo apt-cache'
        alias aptitude='sudo aptitude'
    ;;
    *darwin*)
	    alias emacs="/Applications/Emacs.app/Contents/MacOS/Emacs"
    ;;
    *cygwin*)

    ;;
  *)
    ;;
esac

