# POSIX login base. Shared by sh, by bash (sourced from ~/.bash_profile) and by
# zsh (sourced from ~/.zshenv), so all three agree on PATH and exported env.
#
# Keep this file POSIX: no bashisms, no zsh syntax.
#
# PATH is built HERE and nowhere else. It must not be touched in ~/.bashrc or
# ~/.zshrc: those run only for *interactive* shells, so anything added there is
# invisible to `ssh host cmd`, cron, and make subshells.

# ====================
# PATH HELPERS
# ====================

# Idempotent and existence-checked: re-sourcing this file, or nesting shells,
# must never grow PATH or add a directory that does not exist.
path_prepend() {
	case ":${PATH}:" in
		*":$1:"*) ;;
		*) [ -d "$1" ] && PATH="$1${PATH:+:$PATH}" ;;
	esac
}

path_append() {
	case ":${PATH}:" in
		*":$1:"*) ;;
		*) [ -d "$1" ] && PATH="${PATH:+$PATH:}$1" ;;
	esac
}

# ====================
# PATH
# ====================

# Appended: lower priority than the system paths already present.
path_append /usr/local/sbin
path_append /usr/local/go/bin
path_append "$HOME/go/bin"
path_append "$HOME/bin"

# Prepended: higher priority than system paths. Last prepend wins, so
# ~/.local/bin ends up first -- matching the previous ordering in .bashrc.
path_prepend /opt/local/sbin
path_prepend /opt/local/bin
path_prepend "$HOME/.local/bin"

export PATH

# ====================
# GOOGLE CLOUD SDK
# ====================

# This has lived in several places across machines; probe rather than hardcode.
# Exported so the shell rc files can source the matching completion scripts
# instead of each guessing a different location.
for _gcloud_dir in \
	"$HOME/google-cloud-sdk" \
	"$HOME/bin/google-cloud-sdk" \
	"$HOME/Downloads/google-cloud-sdk" \
	/opt/homebrew/share/google-cloud-sdk \
	/usr/local/share/google-cloud-sdk
do
	if [ -d "$_gcloud_dir" ]; then
		GCLOUD_SDK_ROOT="$_gcloud_dir"
		export GCLOUD_SDK_ROOT
		path_append "$GCLOUD_SDK_ROOT/bin"
		break
	fi
done
unset _gcloud_dir

# ====================
# ENVIRONMENT
# ====================

# emacsclient fails outright when no server is running. ALTERNATE_EDITOR is the
# documented fallback, and the empty string is a special case: it makes
# emacsclient *start the daemon* and reconnect, rather than launching a second,
# unrelated Emacs. Every later call then reuses that daemon.
#
# Setting it as an environment variable rather than as `-a ""` inside $EDITOR is
# deliberate: tools that split $EDITOR on whitespace would pass '' through as a
# literal two-character argument, and the variable also covers a bare
# `emacsclient` typed by hand.
export ALTERNATE_EDITOR=""

# Set once, here, so non-interactive tools (git from a script, sudoedit) see the
# same editor the interactive shell uses. Many tools prefer VISUAL, so set both.
EDITOR="emacsclient -t"
VISUAL="$EDITOR"
export EDITOR VISUAL

export ENABLE_LSP_TOOL=1

# TERM is deliberately NOT set here. The terminal emulator owns it, and
# overriding it breaks tmux (which sets tmux-256color), TRAMP and `ssh host cmd`
# (which use TERM=dumb), and any non-xterm terminal.

# ====================
# RUST
# ====================

# Last: cargo's env prepends ~/.cargo/bin itself, and is already idempotent.
if [ -f "$HOME/.cargo/env" ]; then
	# shellcheck source=/dev/null
	. "$HOME/.cargo/env"
fi
