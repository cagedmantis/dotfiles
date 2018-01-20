#!/bin/bash

echo "bashrc"

# do nothing if this is not interactive
case $- in
	*i*) ;;
	*) return;;
esac

echo "bashrc interactive"

# ========
# Paths
# ========

if [ -d "$HOME/bin/google-cloud-sdk/bin" ]; then
	export PATH=$PATH:$HOME/bin/google-cloud-sdk/bin;
fi

if [ -d "$HOME/bin/android-sdk-linux_86/tools" ]; then
    export PATH=${PATH}:$HOME/bin/android-sdk-linux_86/tools:$HOME/bin
fi

### Added by the Heroku Toolbelt
export PATH="$PATH:/usr/local/heroku/bin"

[ -f /usr/local/etc/bash_completion ] && . /usr/local/etc/bash_completion

# mysql client
export PATH=$PATH:/Applications/MySQLWorkbench.app/Contents/MacOS

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
	xterm-color) color_prompt=yes;;
esac

# System settings
export TERM="xterm-256color"
export DISPLAY=:0.0
export EDITOR="emacsclient -t"
export BROWSER=google-chrome
export GREP_OPTIONS='--color=auto'
export GREP_COLOR='1;31'
export HISTSIZE=10000
export SAVEHIST=10000
export LC_CTYPE=en_US.UTF-8
export HISTCONTROL=ignorespace

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

# print current git branch
function parse_git_branch {
    ref=$(git symbolic-ref HEAD 2> /dev/null) || return
    echo "("${ref#refs/heads/}")"
}

# Prompt
export PS1="\[\033[01;32m\]\u\[\033[01;34m\]@\[\033[01;32m\]\h\[\033[00m\]: \[\e[0;33m\]\w\[\033[00m\] \[\033[0;31m\]\$(parse_git_branch)\[\033[0;37m\]\n$ "

# Aliases
if [ -x /usr/bin/dircolors ]; then
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
    alias la='ls -aAFG'
    alias l='ls -lhFG'
    alias ll='ls -alhFG'
fi

alias tmux='tmux -2'
alias dev='cd ~/Development'
alias c='clear'
alias ping='ping -c 5'
alias df='df -h' 
alias du='du -h -c' 
alias screen='TERM=screen screen'
alias recent="ls -lAt | head"
alias back='cd $OLDPWD'
alias openports='sudo lsof -i -P | grep -i "listen"'
alias weather='curl http://wttr.in/nyc'
alias docker-create-f='docker-machine create --driver vmwarefusion vmdev'
alias docker-create-v='docker-machine create --driver virtualbox --virtualbox-host-dns-resolver vmdev'

# Hai2jessfraz
alias chromekill="ps ux | grep '[C]hrome Helper --type=renderer' | grep -v extension-process | tr -s ' ' | cut -d ' ' -f2 | xargs kill"

alias ec="emacsclient -t"

##os specific config options
case $MACHTYPE in
    *redhat*)
        alias yum='sudo yum'
        alias tree='tree -Ca -I ".git|*.pyc|*.swp"'
		;;
    *linux*)
        alias apt-get='sudo apt-get'
        alias apt-cache='sudo apt-cache'
        alias aptitude='sudo aptitude'
        alias rdesktop='rdesktop -g 1024x800'
		;;
    *darwin*)
	    alias emacs="/Applications/Emacs.app/Contents/MacOS/Emacs"
		alias lockscreen='/System/Library/CoreServices/"Menu Extras"/User.menu/Contents/Resources/CGSession -suspend'

		#eval "$(ssh-agent -s)" >/dev/null 2>&1
		ssh-add -A &> /dev/null

		alias vboxmanage='/Applications/VirtualBox.app/Contents/MacOS/VBoxManage'
		alias vmrun="/Applications/VMware\ Fusion.app/Contents/Library/vmrun"

		export DESKTOP="/Users/carlos/Documents/Virtual Machines.localized/do-desktop.vmwarevm/do-desktop.vmx"
		alias desktop_start="vmrun start \"$DESKTOP\" nogui"
		alias desktop_stop="vmrun stop \"$DESKTOP\" nogui"
		alias desktop_ssh="ssh carlos@172.16.81.100"
		;;
    *cygwin*)
		;;
	*)
		;;
esac

# virtualenvwrapper
if [[ -f /usr/local/bin/virtualenvwrapper.sh ]]; then
	export WORKON_HOME=~/.virtualenvs
	[[ ! -d $WORKON_HOME ]] && mkdir $WORKON_HOME
	source /usr/local/bin/virtualenvwrapper.sh
fi


# direnv
if [ -x "$(command -v direnv)" ]; then
	eval "$(direnv hook bash)"
fi

#============
# Functions
#============

gitBranchPush() {
  git checkout -b $1
  git push -u origin $1
}
alias gbp=gitBranchPush

#=============
# Google Cloud
#=============
if [ -f "$HOME//bin/google-cloud-sdk/completion.bash.inc" ]; then 
	source /Users/carlos/bin/google-cloud-sdk/completion.bash.inc;
fi

if [ -f "$HOME//bin/google-cloud-sdk/path.bash.inc" ]; then 
	source /Users/carlos/bin/google-cloud-sdk/path.bash.inc;
fi


#=============
# Kubernetes
#=============
export KUBECONFIG=/Users/carlos/kubestuff/admin.conf
