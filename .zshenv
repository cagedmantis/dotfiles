# zsh reads this for EVERY invocation -- login, interactive, and every
# non-interactive script or nested shell -- so everything here must be
# idempotent.

# Keep $path (and therefore $PATH) free of duplicates. This is zsh's answer to
# the path_prepend/path_append helpers in ~/.profile, and it is what stops a
# nested shell from growing PATH on each level.
typeset -U path PATH

# Share the POSIX base with sh and bash rather than maintaining a second copy
# of PATH and the environment here. `emulate sh` so POSIX word-splitting and
# globbing rules apply while the file is read.
if [ -f "$HOME/.profile" ]; then
	emulate sh -c '. "$HOME/.profile"'
fi
