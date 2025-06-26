#!/bin/bash

# ====================
# INTERACTIVE CHECK
# ====================

# Do nothing if this is not interactive
case $- in
    *i*) ;;
    *) return;;
esac

# ====================
# HISTORY CONFIGURATION
# ====================

export HISTSIZE=50000
export HISTFILESIZE=50000
export HISTCONTROL=ignorespace:ignoredups:erasedups
export HISTTIMEFORMAT='%F %T '

# ====================
# SHELL OPTIONS
# ====================

# History settings
shopt -s histappend      # Append to history file
shopt -s cmdhist         # Store multiline commands as single entry

# Window and display
shopt -s checkwinsize    # Check window size after each command

# Directory navigation
shopt -s cdspell         # Correct minor spelling errors in cd
shopt -s dirspell        # Correct minor spelling errors in directory names (bash 4+)
shopt -s dotglob         # Include dotfiles in expansion

# Advanced features (bash 4+)
if ((BASH_VERSINFO[0] >= 4)); then
    shopt -s autocd      # Auto-cd when typing directory name
    shopt -s globstar    # Enable ** recursive globbing
fi

# ====================
# COMPLETIONS
# ====================

# Bash completion
if [ -f /usr/local/etc/bash_completion ]; then
    source /usr/local/etc/bash_completion
fi

# Git completion
if [ -f ~/.git-completion.bash ]; then
    source ~/.git-completion.bash
fi

# Kubectl completion
if command -v kubectl &> /dev/null; then
    source <(kubectl completion bash)
fi

# ====================
# PROMPT CONFIGURATION
# ====================

# Git branch function
parse_git_branch() {
    ref=$(git symbolic-ref HEAD 2> /dev/null) || return
    echo "(${ref#refs/heads/})"
}

# Colorful prompt with git info
export PS1="\[\033[01;32m\]\u\[\033[01;34m\]@\[\033[01;32m\]\h\[\033[00m\]: \[\e[0;33m\]\w\[\033[00m\] \[\033[0;31m\]\$(parse_git_branch)\[\033[0;37m\]\n$ "

# ====================
# SSH AGENT
# ====================

if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)"
    ssh-add
fi

# ====================
# ALIASES
# ====================

# Core utilities with colors
if [ -x /usr/bin/dircolors ]; then
    # Linux
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
else
    # macOS
    alias ls='ls -G'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# File listing variations
alias la='ls -aAFG'
alias l='ls -lhFG'
alias ll='ls -alhFG'
alias recent="ls -lAt | head"

# Safety aliases
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'

# Directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias back='cd $OLDPWD'
alias dev='cd ~/Development'

# System utilities
alias c='clear'
alias df='df -h'
alias du='du -h -c'
alias ping='ping -c 5'
alias openports='sudo lsof -i -P | grep -i "listen"'

# Application shortcuts
alias tmux='tmux -2'
alias ec="emacsclient -t"
alias screen='TERM=screen screen'

# Utility functions
alias weather='curl http://wttr.in/nyc'
alias chromekill="ps ux | grep '[C]hrome Helper --type=renderer' | grep -v extension-process | tr -s ' ' | cut -d ' ' -f2 | xargs kill"

# Docker shortcuts
alias docker-create-f='docker-machine create --driver vmwarefusion vmdev'
alias docker-create-v='docker-machine create --driver virtualbox --virtualbox-host-dns-resolver vmdev'

# ====================
# OS-SPECIFIC CONFIGURATION
# ====================

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
        
        # Source Linux-specific config
        if [ -f ~/.bash_linux ]; then
            source ~/.bash_linux
        fi
        ;;
    *darwin*)
        alias emacs="/Applications/Emacs.app/Contents/MacOS/Emacs"
        alias lockscreen='/System/Library/CoreServices/"Menu Extras"/User.menu/Contents/Resources/CGSession -suspend'
        alias vboxmanage='/Applications/VirtualBox.app/Contents/MacOS/VBoxManage'
        alias vmrun="/Applications/VMware\ Fusion.app/Contents/Library/vmrun"
        
        # SSH agent for macOS
        ssh-add -A &> /dev/null
        
        # VMware desktop shortcuts
        export DESKTOP="/Users/carlos/Documents/Virtual Machines.localized/do-desktop.vmwarevm/do-desktop.vmx"
        alias desktop_start="vmrun start \"$DESKTOP\" nogui"
        alias desktop_stop="vmrun stop \"$DESKTOP\" nogui"
        alias desktop_ssh="ssh carlos@172.16.81.100"
        
        # Source macOS-specific config
        if [ -f ~/.bash_osx ]; then
            source ~/.bash_osx
        fi
        ;;
    *cygwin*)
        # Cygwin-specific settings
        ;;
    *)
        # Default settings
        ;;
esac

# ====================
# FUNCTIONS
# ====================

# Git branch creation and push
gitBranchPush() {
    git checkout -b "${1}"
    git push -u origin "${1}"
}
alias gbp=gitBranchPush

# ====================
# EXTERNAL TOOLS
# ====================

# Python virtualenvwrapper
if [[ -f /usr/local/bin/virtualenvwrapper.sh ]]; then
    export WORKON_HOME=~/.virtualenvs
    [[ ! -d $WORKON_HOME ]] && mkdir $WORKON_HOME
    source /usr/local/bin/virtualenvwrapper.sh
fi

# direnv
if command -v direnv &> /dev/null; then
    eval "$(direnv hook bash)"
fi

# Google Cloud SDK
if [ -f "$HOME/bin/google-cloud-sdk/completion.bash.inc" ]; then
    source "$HOME/bin/google-cloud-sdk/completion.bash.inc"
fi

if [ -f "$HOME/bin/google-cloud-sdk/path.bash.inc" ]; then
    source "$HOME/bin/google-cloud-sdk/path.bash.inc"
fi

# Node Version Manager
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Ruby Version Manager
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

# Rust
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

# ====================
# PERSONAL CONFIGURATIONS
# ====================

# Source personal configuration files
if [ -f ~/.bash_profile_ps ]; then
    source "$HOME/.bash_profile_ps"
fi

if [ -f ~/.bash_profile_do ]; then
    source "$HOME/.bash_profile_do"
fi

if [ -f ~/.bash_profile_personal ]; then
    source "$HOME/.bash_profile_personal"
fi