
### Set Path
if [ -d /usr/local/sbin ]; then
	export PATH="${PATH}:/usr/local/sbin"
fi

if [ -d "${HOME}/bin" ]; then
	export PATH="${PATH}:${HOME}/bin"
fi

if [ -d "${HOME}/go/bin" ]; then
	export PATH="${PATH}:${HOME}/go/bin"
fi

if [ -d /usr/local/go/bin ]; then
	export PATH="${PATH}:/usr/local/go/bin"
fi

export EDITOR=/opt/homebrew/bin/emacs

# Rust
. "$HOME/.cargo/env"
