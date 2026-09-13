#!/bin/bash
# Bash login shell.
#
# PATH and exported environment live in ~/.profile so that sh, bash and zsh all
# agree; this file only wires bash up to it and then loads the interactive
# config. Do not add PATH entries here.

if [ -f "$HOME/.profile" ]; then
	# shellcheck source=/dev/null
	. "$HOME/.profile"
fi

if [ -f "${HOME}/.bashrc" ]; then
	# shellcheck source=/dev/null
	. "${HOME}/.bashrc"
fi
