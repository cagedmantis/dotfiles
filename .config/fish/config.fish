#!/usr/bin/env fish

# ====================
# ENVIRONMENT
# ====================

set -g fish_greeting ""

set -gx TERM xterm-256color
set -gx EDITOR "emacsclient -t"
set -gx BROWSER google-chrome

# PATH
fish_add_path $HOME/.local/bin
fish_add_path /opt/local/bin /opt/local/sbin

if test -d $HOME/.cargo/bin
    fish_add_path $HOME/.cargo/bin
end

if test -d $HOME/bin/google-cloud-sdk/bin
    fish_add_path $HOME/bin/google-cloud-sdk/bin
end

# ====================
# PROMPT
# ====================

function fish_prompt
    set -l branch (git branch --show-current 2>/dev/null)
    set -l git_info ""

    if test -n "$branch"
        set -l markers ""
        git diff --cached --quiet 2>/dev/null; or set markers "$markers+"
        git diff --quiet 2>/dev/null; or set markers "$markers*"
        if test -n "$(git ls-files --others --exclude-standard 2>/dev/null | head -1)"
            set markers "$markers?"
        end
        set git_info " "(set_color brblue)"("(set_color brcyan)"$branch$markers"(set_color brblue)")"(set_color normal)
    end

    printf '%s%s%s@%s%s%s: %s%s%s%s\n> %s' \
        (set_color brgreen) $USER (set_color normal) \
        (set_color brgreen) (prompt_hostname) (set_color normal) \
        (set_color blue) (prompt_pwd) (set_color normal) \
        $git_info \
        (set_color normal)
end

# ====================
# ALIASES
# ====================

# Core utilities
if command -q dircolors
    alias ls 'ls --color=auto'
else
    alias ls 'ls -G'
end
alias grep 'grep --color=auto'
alias fgrep 'fgrep --color=auto'
alias egrep 'egrep --color=auto'

# File listing
alias la 'ls -aAFG'
alias l 'ls -lhFG'
alias ll 'ls -alhFG'
alias recent 'ls -lAt | head'

# Safety
alias rm 'rm -i'
alias cp 'cp -i'
alias mv 'mv -i'

# Navigation
alias .. 'cd ..'
alias ... 'cd ../..'
alias .... 'cd ../../..'
alias back 'cd $OLDPWD'
alias dev 'cd ~/Code'

# System
alias c clear
alias r reset
alias df 'df -h'
alias du 'du -h -c'
alias ping 'ping -c 5'
alias openports 'sudo lsof -i -P | grep -i listen'
alias tmux 'tmux -2'
alias ec 'emacsclient -t'
alias weather 'curl http://wttr.in/nyc'
alias chromekill "ps ux | grep '[C]hrome Helper --type=renderer' | grep -v extension-process | tr -s ' ' | cut -d ' ' -f2 | xargs kill"

# Git abbreviations — expand in-place so the full command is visible and editable
abbr -a g git
abbr -a ga 'git add'
abbr -a gaa 'git add -A'
abbr -a gc 'git commit'
abbr -a gcm 'git commit -m'
abbr -a gco 'git checkout'
abbr -a gd 'git diff'
abbr -a gds 'git diff --staged'
abbr -a gl 'git log --oneline'
abbr -a gp 'git push'
abbr -a gpl 'git pull'
abbr -a gs 'git status'
abbr -a gst 'git stash'
abbr -a gstp 'git stash pop'

# ====================
# OS-SPECIFIC
# ====================

switch (uname)
    case Linux
        set -gx DISPLAY :0.0
        abbr -a apt-get 'sudo apt-get'
        abbr -a apt-cache 'sudo apt-cache'
        abbr -a aptitude 'sudo aptitude'
    case Darwin
        alias lockscreen 'pmset displaysleepnow'
        ssh-add -A 2>/dev/null
end

# ====================
# FUNCTIONS
# ====================

function gbp --description 'Create and push a new git branch'
    git checkout -b $argv[1]
    git push -u origin $argv[1]
end

# ====================
# EXTERNAL TOOLS
# ====================

# direnv
if command -q direnv
    eval (direnv hook fish)
end

# Google Cloud SDK
if test -f $HOME/Downloads/google-cloud-sdk/path.fish.inc
    source $HOME/Downloads/google-cloud-sdk/path.fish.inc
end
if test -f $HOME/Downloads/google-cloud-sdk/completion.fish.inc
    source $HOME/Downloads/google-cloud-sdk/completion.fish.inc
end

# Docker CLI completions
if test -d $HOME/.docker/completions
    set -a fish_complete_path $HOME/.docker/completions
end

# Note: NVM and RVM do not natively support Fish.
# For Node version management, use: https://github.com/jorgebucaran/nvm.fish
