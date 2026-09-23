# Helpers shared by the scripts in this directory. Source it after cd'ing to
# the repo root; it defines functions only and has no side effects.

# Prints, one per line, the $HOME-relative paths `make link` installs.
#
# The authoritative list of what `make link` installs is whatever stow says it
# would install; deriving it here would mean reimplementing .stow-local-ignore
# and drifting from it. A throwaway target keeps this a dry run against a
# pristine tree, and overriding HOME stops stow reading a previously installed
# ~/.stow-global-ignore -- the file list must not depend on the machine's state.
#
# --no-folding must match STOW_FLAGS in the Makefile: with folding, stow would
# report a directory such as .config rather than the files inside it.
expected_files() {
	_scratch="${TMPDIR:-/tmp}/dotfiles-expected-$$"
	mkdir -p "$_scratch" || return 1
	# 2>&1 is required, not sloppy: stow writes its dry-run plan to stderr.
	HOME="$_scratch" stow --no --verbose=2 --no-folding --target="$_scratch" . 2>&1 \
		| sed -n 's/^LINK: //p' | sed 's/ =>.*//'
	rm -rf "$_scratch"
}

# Resolves a symlink's target to an absolute path without readlink -f, which
# BSD readlink lacks. Stow writes relative links (~/.zshrc -> Code/GitHub/
# dotfiles/.zshrc), so the target is resolved against the link's own directory.
resolve() {
	_link=$1
	_target=$(readlink "$_link") || return 1
	case $_target in
	/*) printf '%s\n' "$_target" ;;
	*)
		_dir=$(cd "$(dirname "$_link")" 2>/dev/null && cd "$(dirname "$_target")" 2>/dev/null && pwd -P) || return 1
		printf '%s/%s\n' "$_dir" "$(basename "$_target")"
		;;
	esac
}
