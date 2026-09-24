#!/bin/sh
# Install the tmux plugins listed in scripts/tmux-plugins.txt, each checked out
# at its pinned commit under ~/.tmux/plugins.
#
# This does the cloning itself rather than calling tpm's installer, because
# tpm can only pin a plugin to a branch or tag and the catppuccin fork has
# neither. tpm is still what loads the plugins when tmux starts: it runs
# whatever is already in ~/.tmux/plugins, so it runs these pinned checkouts.
#
# Safe to rerun. A plugin already at its pin is left alone, including when
# offline. One at another commit is moved to the pin. One with local edits to
# tracked files, or a directory that is not a git checkout, is reported and
# skipped rather than overwritten. A new plugin is fetched into a temporary
# directory and moved into place only when complete, so an interrupted run
# leaves nothing half-installed. Plugins in ~/.tmux/plugins that are not listed
# are left alone; tpm only loads the plugins named in .tmux.conf.
#
# Exit status: 0 when every plugin is at its pin, 1 otherwise.

set -u

cd "$(dirname "$0")/.." || exit 1
manifest=scripts/tmux-plugins.txt
dest="$HOME/.tmux/plugins"

if ! command -v git >/dev/null 2>&1; then
	echo "tmux-plugins: git is not installed" >&2
	exit 1
fi

# Fail instead of stopping to ask for credentials if a URL is wrong or private.
GIT_TERMINAL_PROMPT=0
export GIT_TERMINAL_PROMPT

mkdir -p "$dest" || exit 1

# Checks out $2 in the existing repository $1, fetching it from $3 first when
# it is not already there. Fetching by commit rather than by branch or tag is
# what makes the pin exact, and a depth of 1 keeps it to a single snapshot.
checkout() {
	if ! git -C "$1" cat-file -e "$2^{commit}" 2>/dev/null; then
		git -C "$1" fetch --quiet --depth 1 "$3" "$2" </dev/null || return 1
	fi
	git -C "$1" -c advice.detachedHead=false checkout --quiet --detach "$2"
}

rc=0
while read -r name url commit rest; do
	case $name in '' | \#*) continue ;; esac
	# Checks the manifest line itself, so a typo reads as one, not as a
	# failed fetch.
	if [ -n "$rest" ] || ! printf '%s\n' "$commit" | grep -Eqx '[0-9a-f]{40}'; then
		echo "tmux-plugins: bad line in $manifest for $name; want: <dir> <url> <40-hex commit>" >&2
		rc=1
		continue
	fi
	dir="$dest/$name"
	short=$(printf '%.7s' "$commit")

	if [ ! -e "$dir" ]; then
		tmp="$dest/.$name.tmp.$$"
		rm -rf "$tmp"
		if git init --quiet "$tmp" && checkout "$tmp" "$commit" "$url" && mv "$tmp" "$dir"; then
			printf '  installed  %s @ %s\n' "$name" "$short"
		else
			rm -rf "$tmp"
			echo "tmux-plugins: could not install $name from $url" >&2
			rc=1
		fi
		continue
	fi

	# .git, not rev-parse: a plain directory inside some other repository
	# (a $HOME kept in git, say) would otherwise pass for a checkout.
	if [ ! -e "$dir/.git" ]; then
		echo "tmux-plugins: $dir exists but is not a git checkout; move it aside and rerun" >&2
		rc=1
		continue
	fi
	head=$(git -C "$dir" rev-parse HEAD 2>/dev/null)
	if [ "$head" = "$commit" ]; then
		printf '  ok         %s @ %s\n' "$name" "$short"
		continue
	fi
	if [ -n "$(git -C "$dir" status --porcelain --untracked-files=no)" ]; then
		echo "tmux-plugins: $dir has local changes; not moving it to $short" >&2
		rc=1
		continue
	fi
	if checkout "$dir" "$commit" "$url"; then
		printf '  updated    %s %.7s -> %s\n' "$name" "$head" "$short"
	else
		echo "tmux-plugins: could not update $name to $short from $url" >&2
		rc=1
	fi
done <"$manifest"

if [ "$rc" -eq 0 ]; then
	echo "tmux-plugins: done. In a running tmux, reload with: tmux source-file ~/.tmux.conf"
fi
exit "$rc"
