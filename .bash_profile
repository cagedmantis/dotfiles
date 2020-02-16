#!/bin/bash

### Set Path
if [ -d /usr/local/sbin ]; then
	export PATH="${PATH}:/usr/local/sbin"
fi

if [ -d "${HOME}/bin" ]; then
	export PATH="${PATH}:${HOME}/bin"
fi

if [ -d /usr/local/go/bin ]; then
	export PATH="${PATH}:/usr/local/go/bin"
fi

### source bashrc
if [ -f "${HOME}/.bashrc" ]; then
	# shellcheck source=/dev/null
    source "${HOME}/.bashrc"
fi
