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

if [ -d "$HOME/bin/google-cloud-sdk/bin" ]; then
	export PATH=$PATH:$HOME/bin/google-cloud-sdk/bin;
fi

if [ -d "$HOME/bin/android-sdk-linux_86/tools" ]; then
    export PATH=${PATH}:$HOME/bin/android-sdk-linux_86/tools:$HOME/bin
fi

# rust
[ -d "${HOME}/.cargo/bin" ] && export PATH="${PATH}:${HOME}/.cargo/bin"
[ -d "${HOME}/.cargo/bin" ] && source "$HOME/.cargo/env"

# System settings
export TERM="xterm-256color"
export EDITOR="emacsclient -t"
export BROWSER=google-chrome
export ENABLE_LSP_TOOL=1
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

# Which VCS owns $PWD? Walks the tree in pure shell -- no subprocess, unlike
# `git rev-parse` / `jj root`. First hit wins, so a colocated repo (both .git
# and .jj present) reports as jj, which is the one you actually drive.
_vcs_kind() {
    local dir="$PWD"
    _VCS_KIND=""
    while [ -n "$dir" ]; do
        if [ -d "$dir/.jj" ]; then _VCS_KIND=jj; return 0; fi
        # -e, not -d: linked worktrees and submodules use a .git *file*
        if [ -e "$dir/.git" ]; then _VCS_KIND=git; return 0; fi
        dir="${dir%/*}"
    done
    return 1
}

# Git branch + status function
# Markers: + staged, * unstaged, ? untracked
parse_git_branch() {
    local ref
    ref=$(git symbolic-ref HEAD 2>/dev/null) || return
    local branch="${ref#refs/heads/}"
    local markers=""
    git diff --cached --quiet 2>/dev/null || markers="${markers}+"
    git diff --quiet 2>/dev/null || markers="${markers}*"
    [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ] && markers="${markers}?"
    echo "(${branch}${markers})"
}

# Jujutsu working-copy info. Renders as (bookmark@changeid<markers>).
# Markers: * working copy non-empty, ! conflicted, ? divergent.
#
# There is no "+" analogue: jj has no index, so the staged/unstaged split does
# not exist. There is no "?" for untracked either -- jj tracks everything in the
# workspace -- so "?" is reused for divergent changes.
#
# --ignore-working-copy is mandatory in a prompt. Without it, *every* prompt
# render snapshots the working copy: it writes a "snapshot working copy" entry
# to the operation log and runs ~5x slower. The cost of the flag is that the
# emptiness marker reflects the last snapshot, not this instant -- it catches up
# the next time any jj command runs. Set DOTFILES_JJ_SNAPSHOT=1 to trade that
# staleness for an always-accurate (but repo-mutating) prompt.
#
# One invocation returns both rows we need: the working copy, and the nearest
# ancestor carrying a bookmark. jj has no "current branch" -- @ is usually a
# fresh empty commit with no bookmark on it at all.
parse_jj_info() {
    command -v jj >/dev/null 2>&1 || return
    local snapshot="--ignore-working-copy"
    [ "${DOTFILES_JJ_SNAPSHOT:-0}" = 1 ] && snapshot=""
    local out tag f2 f3 f4 f5
    local change="" empty="" conflict="" divergent="" bookmark="" markers=""
    out=$(jj $snapshot --no-pager log --color=never --no-graph \
             -r '@ | heads(::@ & bookmarks())' \
             -T 'if(current_working_copy, "WC\t" ++ change_id.shortest(8) ++ "\t" ++ empty ++ "\t" ++ conflict ++ "\t" ++ divergent, "BM\t" ++ local_bookmarks.map(|b| b.name()).join(",")) ++ "\n"' \
             2>/dev/null) || return
    [ -n "$out" ] || return
    while IFS=$'\t' read -r tag f2 f3 f4 f5; do
        case "$tag" in
            WC) change="$f2"; empty="$f3"; conflict="$f4"; divergent="$f5" ;;
            BM) bookmark="${f2%%,*}" ;;
        esac
    done <<< "$out"
    [ "$empty" = false ]     && markers="${markers}*"
    [ "$conflict" = true ]   && markers="${markers}!"
    [ "$divergent" = true ]  && markers="${markers}?"
    echo "(${bookmark}@${change}${markers})"
}

# Dispatch to whichever VCS owns the current directory.
parse_vcs_info() {
    _vcs_kind || return
    case "$_VCS_KIND" in
        jj)  parse_jj_info ;;
        git) parse_git_branch ;;
    esac
}

# Colorful prompt with git info
export PS1="\[\033[01;32m\]\u\[\033[01;33m\]@\[\033[01;32m\]\h\[\033[00m\]: \[\033[01;36m\]\w\[\033[00m\] \[\033[01;34m\]\$(parse_vcs_info)\[\033[00m\]\[\033[01;32m\]\n$ \[\033[00m\]"

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

# ls directory colors: bold cyan on black (macOS + Linux)
export LSCOLORS=GxFxCxDxBxegedabagacad
export LS_COLORS='di=1;36:ln=1;35:so=1;32:pi=1;33:ex=1;31'

# Core utilities with colors
if [ -x /usr/bin/dircolors ]; then
    # Linux
    alias ls='ls --color=auto'
    alias la='ls -aAF --color=auto'
    alias l='ls -lhF --color=auto'
    alias ll='ls -alhF --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
else
    # macOS
    alias ls='ls -G'
    alias la='ls -aAFG'
    alias l='ls -lhFG'
    alias ll='ls -alhFG'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi
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
alias screen='TERM=screen screen'

# Utility functions
alias weather='curl http://wttr.in/nyc'
alias chromekill="ps ux | grep '[C]hrome Helper --type=renderer' | grep -v extension-process | tr -s ' ' | cut -d ' ' -f2 | xargs kill"

# Git aliases
alias g='git'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit'
alias gcm='git commit -m'
alias gco='git checkout'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline'
alias gp='git push'
alias gpl='git pull'
alias gs='git status'
alias gst='git stash'
alias gstp='git stash pop'

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
        export DISPLAY=:0.0
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
        alias lockscreen='pmset displaysleepnow'
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

# MacPorts
export PATH=/opt/local/bin:/opt/local/sbin:$PATH

# Local bin
export PATH="$HOME/.local/bin:$PATH"
