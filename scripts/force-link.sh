#!/bin/sh
# Link this repo into $HOME like `make link`, first moving anything in the way
# to <name>.bak.
#
# `make link` refuses the whole install when any target is already occupied,
# and `make adopt` resolves that by overwriting the repo with $HOME's copy. This
# is the third option: keep both. Each conflicting path is renamed to
# <path>.bak, then stow runs as `make link` does.
#
# What counts as in the way is anything at an expected path that is not already
# a link into this repo: a real file, a directory, a link into another tree, or
# a dangling link. Stow refuses all of them. Deciding this ourselves rather than
# parsing stow's conflict messages keeps it independent of their wording, which
# changes between stow versions.
#
# Safety:
#   * Nothing is ever overwritten. If any <path>.bak already exists, it stops
#     before touching anything; move the old backup away and rerun.
#   * Nothing inside the repo is ever renamed. A $HOME folded by an older stow
#     run without --no-folding reaches repo files through a directory link
#     (~/.config -> repo/.config); those are stow's own links, not conflicts.
#   * If stow still fails after the renames (say ~/.config is a regular file,
#     which is in the way of a directory rather than of a file, and so not
#     something this script moves), every rename is undone.
#
# Exit status: 0 when the link succeeded, 1 otherwise, with $HOME as it was.

set -u

cd "$(dirname "$0")/.." || exit 1
repo=$(pwd -P)
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

if ! command -v stow >/dev/null 2>&1; then
	echo "force-link: stow is not installed" >&2
	exit 1
fi

expected=$(expected_files)
if [ -z "$expected" ]; then
	echo "force-link: stow reported no files to link; is this the package root?" >&2
	exit 1
fi

# Newline-separated lists of $HOME-relative paths. Filenames containing a
# newline are not supported, as in status.sh.
conflicts=''
clashes=''

# Pass 1: decide what to move, changing nothing, so a clash aborts cleanly.
# read -r, not read: a backslash in a filename must survive.
while IFS= read -r f; do
	[ -n "$f" ] || continue
	path="$HOME/$f"

	# Already linked here: nothing to do.
	if [ -L "$path" ] && actual=$(resolve "$path") && [ "$actual" = "$repo/$f" ]; then
		continue
	fi
	# Reached through a directory link into this repo: $path *is* the repo
	# file, and renaming it would rename the repo's copy.
	dir=$(cd "$(dirname "$path")" 2>/dev/null && pwd -P) || dir=''
	case $dir in
	"$repo" | "$repo"/*) continue ;;
	esac
	# -L as well as -e: -e follows the link and is false for a dangling one,
	# which stow refuses all the same.
	if [ -L "$path" ] || [ -e "$path" ]; then
		conflicts="$conflicts$f
"
		if [ -L "$path.bak" ] || [ -e "$path.bak" ]; then
			clashes="$clashes$f
"
		fi
	fi
done <<EOF
$expected
EOF

if [ -n "$clashes" ]; then
	echo "force-link: refusing; these backups already exist and would be overwritten:" >&2
	printf '%s' "$clashes" | sed "s|^|  $HOME/|; s|\$|.bak|" >&2
	echo "Nothing was changed. Move them aside and rerun." >&2
	exit 1
fi

# Pass 2: move the conflicts aside, remembering what was moved for rollback.
moved=''
undo() {
	printf '%s' "$moved" | while IFS= read -r f; do
		# Only restore into an empty slot; never clobber what stow made.
		if [ ! -L "$HOME/$f" ] && [ ! -e "$HOME/$f" ]; then
			mv -- "$HOME/$f.bak" "$HOME/$f" && printf '  restored  %s\n' "$f"
		else
			printf '  kept      %s.bak (%s is occupied)\n' "$f" "$f"
		fi
	done
}

if [ -n "$conflicts" ]; then
	while IFS= read -r f; do
		[ -n "$f" ] || continue
		if ! mv -- "$HOME/$f" "$HOME/$f.bak"; then
			echo "force-link: could not move $HOME/$f; undoing" >&2
			undo
			exit 1
		fi
		moved="$moved$f
"
		printf '  moved     %s -> %s.bak\n' "$f" "$f"
	done <<EOF
$conflicts
EOF
fi

# Pass 3: link. The flags must match STOW_FLAGS in the Makefile.
if ! stow --no-folding --target="$HOME" .; then
	echo "force-link: stow failed; undoing the renames" >&2
	undo
	exit 1
fi

echo "force-link: linked into $HOME"
