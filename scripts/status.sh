#!/bin/sh
# Report whether `make link` has ever been run on this machine.
#
# Stow keeps no manifest: there is no receipt, database or timestamp recording
# an install. The symlinks in $HOME *are* the record, so this asks stow which
# files the package would install, then inspects each of those paths in $HOME
# and classifies what it finds. That also means this reports the state of the
# machine right now, not history -- a link removed by hand reads as missing.
#
# What it deliberately does not do: hunt for stale links. A file dropped from
# the package leaves a dangling link in $HOME that stow no longer mentions, so
# it is invisible here. Finding those means walking $HOME, which is a different
# job (`stow -D` territory) than answering "was this machine ever linked".
#
# Exit status: 0 when every expected file is linked into this repo, 1 otherwise
# (never linked, partially linked, or conflicting). Read-only; it changes
# nothing.

set -u

cd "$(dirname "$0")/.." || exit 1
repo=$(pwd -P)
# shellcheck source=scripts/lib.sh
. scripts/lib.sh

if ! command -v stow >/dev/null 2>&1; then
	echo "status: UNKNOWN -- stow is not installed, so the file list cannot be determined"
	exit 1
fi

expected=$(expected_files)

if [ -z "$expected" ]; then
	echo "status: UNKNOWN -- stow reported no files to link; is this the package root?"
	exit 1
fi

total=0
linked=0
conflicts=0
problems=''

note() { problems="$problems$1
"; }

# read -r, not read: a backslash in a filename must survive.
while IFS= read -r f; do
	[ -n "$f" ] || continue
	total=$((total + 1))
	path="$HOME/$f"

	# -L first, and before -e: -e follows the link and is false for a dangling
	# one, which is a state worth naming rather than calling "missing".
	if [ -L "$path" ]; then
		# No dangling case to handle here: the expected list comes from
		# stow, so $repo/$f exists by construction, and a link resolving
		# to it therefore resolves to something real.
		if actual=$(resolve "$path") && [ "$actual" = "$repo/$f" ]; then
			linked=$((linked + 1))
		else
			note "  foreign   $f -> ${actual:-$(readlink "$path")} (linked to another tree, not this repo)"
		fi
	elif [ -e "$path" ]; then
		conflicts=$((conflicts + 1))
		note "  conflict  $f (a real file, not a link; \`make link\` will refuse it)"
	else
		note "  missing   $f (not linked)"
	fi
done <<EOF
$expected
EOF

echo "== make link =="
printf '  repo      %s\n' "$repo"
printf '  home      %s\n' "$HOME"
printf '  linked    %d of %d files\n' "$linked" "$total"
[ -n "$problems" ] && printf '%s' "$problems"

echo
rc=0
if [ "$linked" -eq "$total" ]; then
	echo "status: LINKED -- \`make link\` has run on this machine"
elif [ "$linked" -eq 0 ]; then
	echo "status: NOT LINKED -- \`make link\` has never run here"
	rc=1
else
	echo "status: PARTIALLY LINKED -- $linked of $total files are linked"
	rc=1
fi

# Conflicts change the advice: stow refuses the whole install rather than
# overwrite, so `make link` alone will not fix them. `make adopt` would, by
# overwriting the repo with $HOME's copy -- which is why it is not suggested;
# `make force-link` keeps both copies.
if [ "$conflicts" -gt 0 ]; then
	printf '        %d path(s) hold a real file; run `make force-link` to move them to *.bak and link\n' "$conflicts"
elif [ "$rc" -ne 0 ]; then
	echo "        run \`make link\` to finish the install"
fi
exit "$rc"
