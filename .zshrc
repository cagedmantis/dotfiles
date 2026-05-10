#!/usr/bin/env zsh

# ====================
# ZSH OPTIONS
# ====================

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY

# Directory navigation
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# Prompt substitution for git info
setopt PROMPT_SUBST

# ====================
# AUTO-COMPLETION
# ====================

autoload -Uz compinit
# Regenerate the dump only once per day; use cached version otherwise
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi

# Case insensitive completion with menu selection
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' menu select

# ====================
# PROMPT CONFIGURATION
# ====================

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

# Set prompt
NEWLINE=$'\n'
PROMPT="%F{10}%n%f%F{11}@%f%F{10}%m%f%F{10}: %f%F{51}%~%f\$(git_prompt_info)%F{10}${NEWLINE}> %f"

# ====================
# ALIASES
# ====================

# ls directory colors: bold cyan on black (macOS + Linux)
export LSCOLORS=GxFxCxDxBxegedabagacad
export LS_COLORS='di=1;36:ln=1;35:so=1;32:pi=1;33:ex=1;31'

# Core utilities with colors
alias ls='ls -G'  # macOS color support
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# File listing variations
alias la='ls -aAFG'
alias l='ls -lhFG'
alias ll='ls -alhFG'
alias recent="ls -lAt | head"

# Safety aliases (interactive mode)
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Directory navigation shortcuts
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias dev='cd ~/Code'

# System utilities
alias c='clear'
alias r='reset'
alias df='df -h'
alias du='du -h -c'
alias ping='ping -c 5'
alias openports='sudo lsof -i -P | grep -i "listen"'

# Application shortcuts
alias tmux='tmux -2'
alias ec="emacsclient -t"

# Utility functions
alias weather='curl http://wttr.in/nyc'
alias chromekill="ps ux | grep '[C]hrome Helper --type=renderer' | grep -v extension-process | tr -s ' ' | cut -d ' ' -f2 | xargs kill"

# ====================
# OS-SPECIFIC CONFIGURATION
# ====================

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
        # Cygwin-specific settings can go here
        ;;
    *)
        # Default settings for other systems
        ;;
esac

export PATH="$HOME/.local/bin:$PATH"
