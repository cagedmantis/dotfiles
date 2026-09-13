#!/usr/bin/env zsh

# ====================
# ZSH OPTIONS
# ====================

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_VERIFY
setopt SHARE_HISTORY

# Directory navigation
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# UX
setopt CORRECT
setopt NO_BEEP

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

# Which VCS owns $PWD? Walks the tree in pure shell -- no subprocess, unlike
# `git rev-parse` / `jj root`. First hit wins, so a colocated repo (both .git
# and .jj present) reports as jj, which is the one you actually drive.
_vcs_kind() {
    local dir="$PWD"
    _VCS_KIND=""
    while [ -n "$dir" ]; do
        if [[ -d "$dir/.jj" ]]; then _VCS_KIND=jj; return 0; fi
        # -e, not -d: linked worktrees and submodules use a .git *file*
        if [[ -e "$dir/.git" ]]; then _VCS_KIND=git; return 0; fi
        dir="${dir%/*}"
    done
    return 1
}

# Git prompt function. Markers: + staged, * unstaged, ? untracked
git_prompt_info() {
    git rev-parse --git-dir > /dev/null 2>&1 || return
    local branch=$(git branch --show-current 2>/dev/null)
    local markers=""
    git diff --cached --quiet 2>/dev/null || markers="${markers}+"
    git diff --quiet 2>/dev/null || markers="${markers}*"
    [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ] && markers="${markers}?"
    echo " %F{12}(%f%F{14}${branch}${markers}%f%F{12})%f"
}

# Jujutsu prompt function. Renders as (bookmark@changeid<markers>), in magenta
# rather than git's blue so the two are distinguishable at a glance -- which
# matters in a colocated repo, where both VCSs are present.
#
# Markers: * working copy non-empty, ! conflicted, ? divergent.
# There is no "+" analogue: jj has no index, so the staged/unstaged split does
# not exist. jj tracks everything in the workspace, so there is no untracked
# state either -- "?" is reused for divergent changes.
#
# --ignore-working-copy is mandatory in a prompt. Without it, *every* prompt
# render snapshots the working copy: it writes a "snapshot working copy" entry
# to the operation log and runs ~5x slower. The cost is that the emptiness
# marker reflects the last snapshot rather than this instant; it catches up the
# next time any jj command runs. Set DOTFILES_JJ_SNAPSHOT=1 to trade that
# staleness for an always-accurate (but repo-mutating) prompt.
#
# One invocation returns both rows: the working copy, and the nearest ancestor
# carrying a bookmark. jj has no "current branch" -- @ is usually a fresh empty
# commit with no bookmark on it at all.
jj_prompt_info() {
    (( $+commands[jj] )) || return
    local snapshot="--ignore-working-copy"
    [[ ${DOTFILES_JJ_SNAPSHOT:-0} == 1 ]] && snapshot=""
    local out tag f2 f3 f4 f5
    local change="" empty="" conflict="" divergent="" bookmark="" markers=""
    out=$(jj ${=snapshot} --no-pager log --color=never --no-graph \
             -r '@ | heads(::@ & bookmarks())' \
             -T 'if(current_working_copy, "WC\t" ++ change_id.shortest(8) ++ "\t" ++ empty ++ "\t" ++ conflict ++ "\t" ++ divergent, "BM\t" ++ local_bookmarks.map(|b| b.name()).join(",")) ++ "\n"' \
             2>/dev/null) || return
    [[ -n "$out" ]] || return
    while IFS=$'\t' read -r tag f2 f3 f4 f5; do
        case "$tag" in
            WC) change="$f2"; empty="$f3"; conflict="$f4"; divergent="$f5" ;;
            BM) bookmark="${f2%%,*}" ;;
        esac
    done <<< "$out"
    [[ $empty == false ]]    && markers="${markers}*"
    [[ $conflict == true ]]  && markers="${markers}!"
    [[ $divergent == true ]] && markers="${markers}?"
    echo " %F{13}(%f%F{14}${bookmark}@${change}${markers}%f%F{13})%f"
}

# Dispatch to whichever VCS owns the current directory.
vcs_prompt_info() {
    _vcs_kind || return
    case "$_VCS_KIND" in
        jj)  jj_prompt_info ;;
        git) git_prompt_info ;;
    esac
}

# Set prompt
NEWLINE=$'\n'
PROMPT="%F{10}%n%f%F{11}@%f%F{10}%m%f%F{10}: %f%F{51}%~%f\$(vcs_prompt_info)%F{10}${NEWLINE}> %f"

# ====================
# ENVIRONMENT
# ====================

export TERM="xterm-256color"
export EDITOR="emacsclient -t"
export BROWSER=google-chrome
export ENABLE_LSP_TOOL=1

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
alias mkdir='mkdir -p'

# Directory navigation shortcuts
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
        export DISPLAY=:0.0
        alias apt-get='sudo apt-get'
        alias apt-cache='sudo apt-cache'
        alias aptitude='sudo aptitude'
        alias rdesktop='rdesktop -g 1024x800'
        ;;
    *darwin*)
        alias lockscreen='pmset displaysleepnow'
        # Only load keychain keys if the agent has none yet; quiet, never blocking.
        if ! ssh-add -l >/dev/null 2>&1; then
            ssh-add -q --apple-load-keychain 2>/dev/null || ssh-add -q -A 2>/dev/null
        fi
        ;;
    *cygwin*)
        # Cygwin-specific settings can go here
        ;;
    *)
        # Default settings for other systems
        ;;
esac

# ====================
# FUNCTIONS
# ====================

gbp() {
    git checkout -b "${1}"
    git push -u origin "${1}"
}

# ====================
# EXTERNAL TOOLS
# ====================

# direnv
if command -v direnv &> /dev/null; then
    eval "$(direnv hook zsh)"
fi

# Google Cloud SDK
if [ -f "$HOME/Downloads/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/Downloads/google-cloud-sdk/path.zsh.inc"; fi
if [ -f "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc"; fi

# Docker CLI completions
fpath=("$HOME/.docker/completions" $fpath)

# MacPorts
export PATH=/opt/local/bin:/opt/local/sbin:$PATH

export PATH="$HOME/.local/bin:$PATH"
