#!/usr/bin/env zsh

# This entire file is a wip

# Aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias la='ls -aAFG'
alias l='ls -lhFG'
alias ll='ls -alhFG'

# TODO review
alias tmux='tmux -2'
alias dev='cd ~/Code'
alias c='clear'
alias r='reset'
alias ping='ping -c 5'
alias df='df -h'
alias du='du -h -c'
alias recent="ls -lAt | head"
alias openports='sudo lsof -i -P | grep -i "listen"'
alias weather='curl http://wttr.in/nyc'

# Hai2jessfraz
alias chromekill="ps ux | grep '[C]hrome Helper --type=renderer' | grep -v extension-process | tr -s ' ' | cut -d ' ' -f2 | xargs kill"

alias ec="emacsclient -t"

##os specific config options
case $OSTYPE in
    *linux*)
        alias apt-get='sudo apt-get'
        alias apt-cache='sudo apt-cache'
        alias aptitude='sudo aptitude'
        alias rdesktop='rdesktop -g 1024x800'
		;;
    *darwin*)
		alias lockscreen='pmset displaysleepnow'
		;;
    *cygwin*)
		;;
	*)
		;;
esac

NEWLINE=$'\n'
PROMPT="%F{10}%n%f%F{11}@%f%F{10}%m%f%F{10}: %f%F{33}%~%f%F{10}${NEWLINE}> %f"
