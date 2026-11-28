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

# Completion search path must be complete BEFORE compinit runs -- compinit
# scans fpath once, so anything appended afterwards is silently ignored for the
# life of the shell. (Docker's completions used to be added at the bottom of
# this file and therefore never loaded.)
[[ -d "$HOME/.docker/completions" ]] && fpath=("$HOME/.docker/completions" $fpath)
[[ -d /opt/homebrew/share/zsh/site-functions ]] && fpath=(/opt/homebrew/share/zsh/site-functions $fpath)

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
# Sets _VCS_KIND (jj or git) and _VCS_ROOT (the directory holding it).
_vcs_kind() {
    local dir="$PWD"
    _VCS_KIND="" _VCS_ROOT=""
    while [ -n "$dir" ]; do
        if [[ -d "$dir/.jj" ]]; then _VCS_KIND=jj _VCS_ROOT=$dir; return 0; fi
        # -e, not -d: linked worktrees and submodules use a .git *file*
        if [[ -e "$dir/.git" ]]; then _VCS_KIND=git _VCS_ROOT=$dir; return 0; fi
        dir="${dir%/*}"
    done
    return 1
}

# Git prompt function.
# Markers: + staged, * unstaged, ? untracked.
#
# One `git status --porcelain=v2 --branch` replaces the five separate git
# invocations this used to make (symbolic-ref, diff --cached, diff, ls-files
# --others). Measured on this repo: 46ms -> 12ms per prompt render, and
# `ls-files --others` was the expensive one on a large worktree.
#
# Format: "# branch.head <name>" carries the branch, or the literal
# "(detached)"; "1"/"2" lines carry a two-character XY status where X is the
# staged state and Y the unstaged one, "." meaning unchanged; "u" lines are
# unmerged; "?" lines are untracked.
# Hardening: git reads the *repository's own* .git/config
# before doing anything, and core.fsmonitor is a command git executes. A repo
# you merely `cd` into -- an unpacked tarball, a cloned PR branch -- therefore
# gets arbitrary code execution once per prompt render. Verified: 1 execution
# per render before this flag, 0 after, with branch and dirty state unchanged.
# diff.external is neutralised for the same reason.
git_prompt_info() {
    local line xy branch="" oid="" staged="" unstaged="" untracked=""
    while IFS= read -r line; do
        case $line in
            '# branch.head '*) branch=${line#\# branch.head } ;;
            '# branch.oid '*)  oid=${line#\# branch.oid } ;;
            '1 '*|'2 '*)
                xy=${line:2:2}
                [[ ${xy%?} != "." ]] && staged="+"
                [[ ${xy#?} != "." ]] && unstaged="*"
                ;;
            'u '*) unstaged="*" ;;
            '? '*) untracked="?" ;;
        esac
    done < <(git -c core.fsmonitor= -c diff.external= status --porcelain=v2 --branch 2>/dev/null)
    [[ -n $branch ]] || return
    [[ $branch == "(detached)" ]] && branch="@${oid:0:7}"
    echo " %F{12}(%f%F{14}${branch}${staged}${unstaged}${untracked}%f%F{12})%f"
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
#
# Needs jj 0.22+ (the first release with bookmarks). Any failure returns
# non-zero so vcs_prompt_info can fall back to git in a colocated repo.
#
# Hardening (see parse_jj_info in .bashrc for the full story): a plain-file
# .jj/repo/config.toml is pre-0.38 repo config that jj would adopt and trust,
# so such a repo is skipped until you run jj there yourself; and the overrides
# pin signing and fsmonitor, the two settings that can run a program here.
jj_prompt_info() {
    (( $+commands[jj] )) || return
    [[ -f $_VCS_ROOT/.jj/repo/config.toml && ! -L $_VCS_ROOT/.jj/repo/config.toml ]] && return 1
    local snapshot="--ignore-working-copy"
    [[ ${DOTFILES_JJ_SNAPSHOT:-0} == 1 ]] && snapshot=""
    local out tag f2 f3 f4 f5
    local change="" empty="" conflict="" divergent="" bookmark="" markers=""
    out=$(jj ${=snapshot} --no-pager --config signing.behavior=drop --config fsmonitor.backend=none \
             log --color=never --no-graph \
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

# Dispatch to whichever VCS owns the current directory. In a colocated repo
# a failed jj prompt falls back to git; a pure jj repo has no .git of its own
# and must not pick up an enclosing git repo.
vcs_prompt_info() {
    _vcs_kind || return
    case "$_VCS_KIND" in
        jj)  jj_prompt_info || { [[ -e $_VCS_ROOT/.git ]] && git_prompt_info; } ;;
        git) git_prompt_info ;;
    esac
}

# Set prompt
NEWLINE=$'\n'
PROMPT="%F{10}%n%f%F{11}@%f%F{10}%m%f%F{10}: %f%F{51}%~%f\$(vcs_prompt_info)%F{10}${NEWLINE}> %f"

# Turn terminal mouse reporting off before every prompt. tmux (mouse on),
# vim, htop etc. enable it and disable it on a clean exit; when one dies
# instead -- most often a dropped SSH session to a remote tmux -- the terminal
# keeps reporting, and every mouse move types "35;120;21M" garbage at the
# prompt. A prompt never wants mouse input, so this is always safe, and inside
# tmux it only touches the pane, not tmux's own mouse mode.
# Modes: 1000 click, 1002 drag, 1003 any-motion, 1006 SGR, 1015 urxvt.
_reset_mouse_tracking() { printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?1015l'; }
autoload -Uz add-zsh-hook
add-zsh-hook precmd _reset_mouse_tracking

# ====================
# ENVIRONMENT
# ====================

# TERM, EDITOR/VISUAL, ENABLE_LSP_TOOL and PATH all come from ~/.profile,
# sourced by ~/.zshenv. TERM in particular must not be set by a shell: the
# terminal emulator owns it, and overriding it defeats tmux's tmux-256color.
export BROWSER=google-chrome

# ====================
# ALIASES
# ====================

# ls directory colors: bold cyan on black (macOS + Linux)
export LSCOLORS=GxFxCxDxBxegedabagacad
export LS_COLORS='di=1;36:ln=1;35:so=1;32:pi=1;33:ex=1;31'

# Core utilities with colors.
#
# -G means "colour" on BSD/macOS ls but "suppress the group column" on GNU
# coreutils, so the flag must be chosen per platform rather than hardcoded.
# dircolors exists only in coreutils, which makes it a reliable probe.
if (( $+commands[dircolors] )); then
    # GNU / Linux
    alias ls='ls --color=auto'
    alias la='ls -aAF --color=auto'
    alias l='ls -lhF --color=auto'
    alias ll='ls -alhF --color=auto'
else
    # BSD / macOS
    alias ls='ls -G'
    alias la='ls -aAFG'
    alias l='ls -lhFG'
    alias ll='ls -alhFG'
fi
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
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

# Jujutsu. One shell alias, like g=git; the rest are jj aliases in
# ~/.config/jj/conf.d/dotfiles.toml, so every shell shares one copy.
alias j='jj'

# Application shortcuts
alias ec="emacsclient -t"

# Utility functions
alias weather='curl https://wttr.in/nyc'

# ====================
# OS-SPECIFIC CONFIGURATION
# ====================

case $OSTYPE in
    *linux*)
        # Adopt the systemd user agent (Debian 13+): it only exports
        # SSH_AUTH_SOCK to the systemd user environment, which SSH logins miss.
        if [[ -z $SSH_AUTH_SOCK && -S $XDG_RUNTIME_DIR/openssh_agent ]]; then
            export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/openssh_agent
        fi
        ;;
    *darwin*)
        alias lockscreen='pmset displaysleepnow'
        # Only load keychain keys if the agent has none yet; quiet, never blocking.
        if ! ssh-add -l >/dev/null 2>&1; then
            ssh-add -q --apple-load-keychain 2>/dev/null || ssh-add -q -A 2>/dev/null
        fi
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

# Kubectl completion. bash had this and zsh did not, so completions differed by
# shell. compinit has already run by this point, which is what compdef needs.
if (( $+commands[kubectl] )); then
    source <(kubectl completion zsh)
fi

# Source the completion script "$@" prints for tool $1, cached under
# ~/.cache/dotfiles and regenerated only when the tool's binary is newer than
# the cache (an upgrade), so a shell start costs no exec of the tool.
_cached_completion() {
    local name=$1 bin cache
    shift
    bin=${commands[$name]:-}
    [[ -n $bin ]] || return
    cache="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/$name-completion.zsh"
    if [[ ! -s $cache || $bin -nt $cache ]]; then
        mkdir -p "${cache:h}" || return
        if ! "$@" >"$cache.$$" 2>/dev/null || [[ ! -s $cache.$$ ]]; then
            rm -f "$cache.$$"
            return 1
        fi
        mv -f "$cache.$$" "$cache"
    fi
    source "$cache"
}

# Jujutsu completion: jj's dynamic script, static text that calls `jj` at
# completion time, which is what makes caching it safe. Needs compdef, so it
# stays after compinit.
(( $+commands[jj] )) && _cached_completion jj env COMPLETE=zsh jj

# Google Cloud SDK
# GCLOUD_SDK_ROOT is probed once in ~/.profile; every shell uses that answer
# rather than each hardcoding a different guess. path.zsh.inc only edits PATH,
# which ~/.profile already handles, so only completions are sourced here.
if [[ -n $GCLOUD_SDK_ROOT && -f "$GCLOUD_SDK_ROOT/completion.zsh.inc" ]]; then
    . "$GCLOUD_SDK_ROOT/completion.zsh.inc"
fi

# ====================
# LOCAL OVERRIDES
# ====================

# ~/.shell_local is sourced earlier by ~/.profile (via ~/.zshenv) and holds
# environment shared with sh and bash. This is for zsh-only interactive
# settings that must land after everything above.
[[ -f "$HOME/.zshrc_local" ]] && source "$HOME/.zshrc_local"
