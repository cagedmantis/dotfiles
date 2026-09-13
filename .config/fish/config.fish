#!/usr/bin/env fish

# ====================
# ENVIRONMENT
# ====================

set -g fish_greeting ""

# Fish cannot source ~/.profile, so this block mirrors it. Keep the two in
# sync -- ~/.profile is the reference.
#
# TERM is deliberately NOT set: the terminal emulator owns it, and overriding
# it defeats tmux's tmux-256color.
# emacsclient fails outright when no server is running. ALTERNATE_EDITOR is the
# documented fallback; the empty string is a special case that makes emacsclient
# start the daemon and reconnect, rather than launching a second, unrelated
# Emacs. Kept as an environment variable rather than `-a ""` inside $EDITOR so
# that a bare `emacsclient` is covered too. Mirrors ~/.profile.
set -gx ALTERNATE_EDITOR ""
set -gx EDITOR "emacsclient -t"
set -gx VISUAL $EDITOR
set -gx BROWSER google-chrome
set -gx ENABLE_LSP_TOOL 1

# PATH. fish_add_path is idempotent and skips directories that do not exist,
# which is why no explicit guards are needed here.
#
# -P/--path is required. Without it fish_add_path writes to $fish_user_paths, a
# *universal* variable that is persisted outside this repo and prepended to
# $PATH as a whole block -- so appended entries would still land ahead of
# /usr/bin, and this machine would disagree with a fresh one. -P edits $PATH
# directly, giving the same precedence as ~/.profile.
fish_add_path -aP /usr/local/sbin /usr/local/go/bin $HOME/go/bin $HOME/bin
fish_add_path -P /opt/local/sbin /opt/local/bin $HOME/.cargo/bin $HOME/.local/bin

# Known, harmless divergence from ~/.profile: rustup drops a conf.d/rustup.fish
# that sources ~/.cargo/env.fish, and fish runs conf.d/ *before* config.fish.
# ~/.cargo/bin is therefore already on PATH by the time the line above runs, and
# fish_add_path will not relocate an entry it already finds -- so .local/bin
# ends up ahead of .cargo/bin here, while ~/.profile has them the other way
# round. Both directories are present with the same precedence relative to the
# system paths, and nothing is installed under both names, so this is cosmetic.

# Google Cloud SDK: probe the locations this has lived in, matching ~/.profile.
for _gcloud_dir in $HOME/google-cloud-sdk $HOME/bin/google-cloud-sdk \
        $HOME/Downloads/google-cloud-sdk /opt/homebrew/share/google-cloud-sdk \
        /usr/local/share/google-cloud-sdk
    if test -d $_gcloud_dir
        set -gx GCLOUD_SDK_ROOT $_gcloud_dir
        fish_add_path -aP $_gcloud_dir/bin
        break
    end
end
set -e _gcloud_dir

# ====================
# PROMPT
# ====================

# Which VCS owns $PWD? Walks the tree in pure fish -- no subprocess, unlike
# `git rev-parse` / `jj root`. First hit wins, so a colocated repo (both .git
# and .jj present) reports as jj, which is the one you actually drive.
function _vcs_kind --description 'Echo jj or git for the repo owning $PWD'
    set -l dir $PWD
    while test -n "$dir"
        if test -d "$dir/.jj"
            echo jj
            return 0
        end
        # -e, not -d: linked worktrees and submodules use a .git *file*
        if test -e "$dir/.git"
            echo git
            return 0
        end
        set dir (string replace -r '/[^/]*$' '' -- $dir)
    end
    return 1
end

# Git status fragment. Markers: + staged, * unstaged, ? untracked
function _git_prompt_info --description 'Coloured git branch + status fragment'
    set -l branch (git branch --show-current 2>/dev/null)
    if test -z "$branch"
        # Detached HEAD -- also `git bisect` and `worktree add --detach` -- has
        # no branch name. Show the short commit rather than rendering nothing.
        # The "@" prefix matches the jj format, where a bare @changeid likewise
        # means "no name to show here".
        set branch "@"(git rev-parse --short HEAD 2>/dev/null)
        test "$branch" = "@"; and return 1
    end
    set -l markers ""
    git diff --cached --quiet 2>/dev/null; or set markers "$markers+"
    git diff --quiet 2>/dev/null; or set markers "$markers*"
    if test -n "$(git ls-files --others --exclude-standard 2>/dev/null | head -1)"
        set markers "$markers?"
    end
    echo -n " "(set_color brblue)"("(set_color brcyan)"$branch$markers"(set_color brblue)")"(set_color normal)
end

# Jujutsu status fragment. Renders as (bookmark@changeid<markers>), in magenta
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
function _jj_prompt_info --description 'Coloured jj change + bookmark fragment'
    command -q jj; or return 1
    set -l snapshot --ignore-working-copy
    if test "$DOTFILES_JJ_SNAPSHOT" = 1
        set snapshot
    end
    set -l out (jj $snapshot --no-pager log --color=never --no-graph \
        -r '@ | heads(::@ & bookmarks())' \
        -T 'if(current_working_copy, "WC\t" ++ change_id.shortest(8) ++ "\t" ++ empty ++ "\t" ++ conflict ++ "\t" ++ divergent, "BM\t" ++ local_bookmarks.map(|b| b.name()).join(",")) ++ "\n"' \
        2>/dev/null)
    or return 1
    test -n "$out"; or return 1

    set -l change ""
    set -l bookmark ""
    set -l markers ""
    for line in $out
        set -l f (string split \t -- $line)
        switch $f[1]
            case WC
                set change $f[2]
                test "$f[3]" = false; and set markers "$markers*"
                test "$f[4]" = true; and set markers "$markers!"
                test "$f[5]" = true; and set markers "$markers?"
            case BM
                if set -q f[2]
                    set bookmark (string replace -r ',.*$' '' -- $f[2])
                end
        end
    end
    echo -n " "(set_color brmagenta)"("(set_color brcyan)"$bookmark@$change$markers"(set_color brmagenta)")"(set_color normal)
end

function fish_prompt
    set -l vcs_info ""
    switch (_vcs_kind)
        case jj
            set vcs_info (_jj_prompt_info)
        case git
            set vcs_info (_git_prompt_info)
    end

    printf '%s%s%s@%s%s%s: %s%s%s%s\n> %s' \
        (set_color brgreen) $USER (set_color normal) \
        (set_color brgreen) (prompt_hostname) (set_color normal) \
        (set_color blue) (prompt_pwd) (set_color normal) \
        "$vcs_info" \
        (set_color normal)
end

# ====================
# ALIASES
# ====================

# Core utilities.
#
# -G means "colour" on BSD/macOS ls but "suppress the group column" on GNU
# coreutils, so every listing alias must pick its flags per platform -- not
# just `ls`, which is how la/l/ll previously ended up wrong on Linux.
if command -q dircolors
    # GNU / Linux
    alias ls 'ls --color=auto'
    alias la 'ls -aAF --color=auto'
    alias l 'ls -lhF --color=auto'
    alias ll 'ls -alhF --color=auto'
else
    # BSD / macOS
    alias ls 'ls -G'
    alias la 'ls -aAFG'
    alias l 'ls -lhFG'
    alias ll 'ls -alhFG'
end
alias grep 'grep --color=auto'
alias fgrep 'fgrep --color=auto'
alias egrep 'egrep --color=auto'
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
alias ec 'emacsclient -t'
alias weather 'curl https://wttr.in/nyc'
# xargs -r is GNU-only, so filter empties explicitly: bare `xargs kill` runs
# `kill` with no arguments when nothing matches.
function chromekill --description 'Kill hung Chrome renderer processes'
    for pid in (ps ux | grep '[C]hrome Helper --type=renderer' \
            | grep -v extension-process | tr -s ' ' | cut -d ' ' -f2)
        test -n "$pid"; and kill $pid
    end
end

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
        # Only when nothing else has set it, and never over SSH: forcing
        # DISPLAY breaks `ssh -X` (which sets localhost:10.0) and Wayland.
        if test -z "$DISPLAY" -a -z "$SSH_CONNECTION"
            set -gx DISPLAY :0.0
        end
        abbr -a apt-get 'sudo apt-get'
        abbr -a apt-cache 'sudo apt-cache'
        abbr -a aptitude 'sudo aptitude'
    case Darwin
        alias lockscreen 'pmset displaysleepnow'
        # Only load keychain keys if the agent has none yet; quiet, never blocking.
        if not ssh-add -l >/dev/null 2>&1
            ssh-add -q --apple-load-keychain 2>/dev/null
            or ssh-add -q -A 2>/dev/null
        end
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
# GCLOUD_SDK_ROOT is probed above, matching ~/.profile. path.fish.inc only
# edits PATH, which fish_add_path already handled, so only completions load.
if set -q GCLOUD_SDK_ROOT; and test -f $GCLOUD_SDK_ROOT/completion.fish.inc
    source $GCLOUD_SDK_ROOT/completion.fish.inc
end

# Docker CLI completions
if test -d $HOME/.docker/completions
    set -a fish_complete_path $HOME/.docker/completions
end

# Note: NVM and RVM do not natively support Fish.
# For Node version management, use: https://github.com/jorgebucaran/nvm.fish
