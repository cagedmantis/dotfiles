#!/usr/bin/env zsh

# ====================
# HISTORY CONFIGURATION
# ====================

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY

# ====================
# AUTO-COMPLETION
# ====================

# Enable auto-completion
autoload -Uz compinit
compinit

# Case insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu select

# ====================
# DIRECTORY NAVIGATION
# ====================

# Auto-cd when typing directory name
setopt AUTO_CD

# Directory stack options
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# ====================
# ALIASES
# ====================
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
# Modern ls alternatives  
alias la='ls -aAFG'
alias l='ls -lhFG'
alias ll='ls -alhFG'

# Safety aliases
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Directory shortcuts
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

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

# Git prompt function
git_prompt_info() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        local branch=$(git branch --show-current 2>/dev/null)
        local git_status=""
        
        # Check for uncommitted changes
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            git_status="*"
        fi
        
        # Check for untracked files
        if [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
            git_status="${git_status}+"
        fi
        
        echo " %F{12}(%f%F{14}${branch}${git_status}%f%F{12})%f"
    fi
}

NEWLINE=$'\n'
setopt PROMPT_SUBST
PROMPT="%F{10}%n%f%F{11}@%f%F{10}%m%f%F{10}: %f%F{33}%~%f\$(git_prompt_info)%F{10}${NEWLINE}> %f"
