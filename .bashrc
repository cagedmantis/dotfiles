# ~/.bashrc
# Carlos Amedee
# www.amedee.net

# If not running interactively, don't do anything
# [ -z "$PS1" ] && return


# shopt settings
shopt -s histappend # append to the history file, don't overwrite it
shopt -s checkwinsize # Check the window size.
shopt -s cdspell # This will correct minor spelling errors in a cd command.
shopt -s dotglob # files beginning with . to be returned in the results of path-name expansion.

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

force_color_prompt=yes
if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\n\$ '

unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# Paths
export CLASSPATH=
export CLOJURE_EXT=$HOME/.clojure
if [ -d $HOME/bin ]; then
    export PATH=${PATH}:$HOME/bin/android-sdk-linux_86/tools:$HOME/bin
fi

# System settings
export TERM="xterm-color"
export DISPLAY=:0.0
export EDITOR=emacs

# Alias
## System
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias la='ls -A'
    alias l='ls -CF'
    alias l='ls -lah' 
    alias la='ls -AF' 
    alias ll='ls -lFh' 
    alias grep='grep --color=auto' 
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
else
    alias la='ls -A'
    alias l='ls -CF'
    alias l='ls -lah' 
    alias la='ls -AF' 
    alias ll='ls -lFh' 
fi

alias rdesktop='rdesktop -g 1024x800'
alias ping='ping -c 5'
alias df='df -h' 
alias du='du -h -c' 
alias sgi='sudo gem install'
alias screen='TERM=screen screen'
alias recent="ls -lAt | head"
alias back='cd $OLDPWD'
alias rtfm='man'
alias openports='sudo lsof -i -P | grep -i "listen"'

## Debian/Ubuntu
alias apt-get='sudo apt-get'
alias apt-cache='sudo apt-cache'
alias aptitude='sudo aptitude'

## Redhat/Centos/Fedora
alias yum='sudo yum'
alias tree='tree -Ca -I ".git|*.pyc|*.swp"'

## Git
alias ga='git add'
alias gb='git branch'
alias gba='git branch -a'
alias gc='git commit -v'
alias gl='git pull'
alias gp='git push'
alias gst='git status'
alias gsd='git svn dcommit'
alias gsr='git svn rebase'
alias gs='git stash'
alias gsa='git stash apply'
alias gr='git stash && git svn rebase && git svn dcommit && git stash pop'
alias gd='git diff | $GIT_EDITOR -'
alias gmv='git mv'
alias gho='$(git remote -v 2> /dev/null | grep github | sed -e "s/.*git\:\/\/\([a-z]\.\)*/\1/" -e "s/\.git$//g" -e "s/.*@\(.*\)$/\1/g" | tr ":" "/" | tr -d "\011" | sed -e "s/^/open http:\/\//g")'

## OSX
alias port='sudo port'
