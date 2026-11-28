# Dotfiles

Personal shell configuration files and environment settings for macOS/Linux development environments.

## Overview

This repository contains my personal dotfiles including shell configurations (bash, zsh and fish), terminal multiplexer settings (tmux), and various development environment configurations. The setup is optimized for software development with features like git-aware prompts, modern shell options, and convenient aliases.

## Features

### Shell Configuration
- **Bash**: Enhanced history, safety aliases, git-aware prompt, OS-specific configurations
- **Zsh**: Modern shell options, auto-completion, directory navigation shortcuts, git integration
- **Fish**: The same prompt, aliases and environment, with git shortcuts as abbreviations
- **One environment for every shell**: PATH and exported variables are set once in `.profile` (fish mirrors it)
- **Cross-platform**: Works on macOS and Linux

### Terminal Multiplexer
- **Tmux**: Custom key bindings, enhanced status bar, optimized for development workflows

### Development Tools Integration
- Git and Jujutsu (jj) state in the prompt, jj aliases and completion
- direnv hook for per-project environments
- Rust (`~/.cargo/env`) and Go on PATH
- Google Cloud SDK integration
- Kubernetes (kubectl), Docker and jj completion

## Installation

### Prerequisites

- Git
- GNU Stow
- tmux 3.2 or newer (the config uses `terminal-features` and `extended-keys`)
- On Linux, a clipboard tool for tmux-yank: `xclip`, `xsel`, or `wl-copy` (from
  `wl-clipboard`) on Wayland. macOS has `pbcopy` built in.
- For fish: fish 3.6 or newer (the prompt uses `"$(...)"`, the jj completion
  cache `path mtime`)
- Optional: jj 0.28 or newer for the jj aliases (the prompt alone works from
  0.22)

#### Install GNU Stow

**macOS:**
```bash
brew install stow
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install stow
```

**Linux (CentOS/RHEL):**
```bash
sudo yum install stow
```

### Quick Setup

1. Clone the repository:
```bash
git clone https://github.com/cagedmantis/dotfiles.git ~/Code/Github/dotfiles
cd ~/Code/Github/dotfiles
```

2. Link the files and install the tmux plugins in one step:
```bash
make install
```
This runs `make link` (symlinks via GNU Stow), `make tmux-plugins` (tpm,
catppuccin and tmux-yank, each checked out at the commit pinned in
`scripts/tmux-plugins.txt`) and `make status`. You can also run the steps
individually. Skip the plugins and tmux still starts, but with the default
status bar and no clipboard integration. Rerun `make tmux-plugins` after
changing a pin.

3. Reload your shell:
```bash
# For bash
source ~/.bashrc

# For zsh  
source ~/.zshrc
```

### Alternative Installation Methods

#### Manual Symlink Creation
```bash
# Create symlinks manually (the flags must match STOW_FLAGS in the Makefile)
stow --no-folding --target=$HOME .
```

#### Replace Existing Files
If `make link` refuses because files already exist in `$HOME`, move them aside
to `<name>.bak` and link in one step:
```bash
make force-link
```
It never overwrites: if a `.bak` already exists it stops without changing
anything, and if stow still fails it undoes the renames.

#### Adopt Existing Files
To pull your existing `$HOME` copies *into this repo*, overwriting the tracked
versions (review with `git diff` afterwards):
```bash
make adopt CONFIRM=1
```
Without `CONFIRM=1` it refuses and changes nothing. It prints `git diff --stat`
when done.

#### Uninstall
```bash
make unlink
```
Removes the symlinks `make link` created. Real files in `$HOME` are left alone.

Run `make` with no target to list every target.

## Configuration Files

| File | Purpose |
|------|---------|
| `.profile` | POSIX base: PATH, EDITOR/VISUAL and exported env, shared by sh, bash and zsh |
| `.bash_profile` | Bash login shell; sources `.profile` then `.bashrc` |
| `.bashrc` | Bash interactive configuration: prompt, aliases, functions |
| `.zshenv` | Zsh, every invocation; dedupes PATH and sources `.profile` |
| `.zshrc` | Zsh interactive configuration: options, completion, prompt, aliases |
| `.config/fish/config.fish` | Fish configuration; mirrors `.profile` and the bash/zsh aliases |
| `.tmux.conf` | Tmux terminal multiplexer configuration |
| `.config/jj/conf.d/dotfiles.toml` | jj aliases shared by every shell; your own jj settings stay in `~/.config/jj/config.toml` |
| `.gitignore` | Files to ignore in this repository (not linked into `$HOME`) |
| `.stow-local-ignore` | Files for Stow to ignore when symlinking (must be named `.stow-local-ignore`; Stow does not read a `.stow-global-ignore` placed inside a package) |

## Key Features

### Bash Configuration
- **Enhanced history**: 50K entries with timestamps and deduplication
- **Safety aliases**: Interactive prompts for `rm`, `cp`, `mv`
- **Git integration**: Branch information in prompt
- **OS detection**: Platform-specific aliases and settings
- **Development tools**: Integration with Docker, Node.js, Python, etc.

### Zsh Configuration
- **Modern shell options**: Auto-completion, directory navigation, history management
- **Git-aware prompt**: Shows branch name and status indicators
- **Smart aliases**: Directory shortcuts, safety features, productivity helpers
- **No plugin manager**: plain zsh, so startup stays fast

### Tmux Configuration
- **Custom prefix**: `Ctrl-g` (better for Emacs users)
- **Intuitive bindings**: `|` for horizontal split, `-` for vertical split
- **Enhanced status bar**: Catppuccin (mocha) theme, via a plugin; shows the machine name when tmux was started over SSH
- **Clipboard**: tmux-yank copies to the system clipboard, including over SSH
- **Pinned plugins**: installed by `make tmux-plugins` at exact commits, not
  the latest code. Avoid tpm's `prefix + I` and `prefix + U`, which fetch the
  latest code; change the pin in `scripts/tmux-plugins.txt` instead
- **Mouse support**: Enabled for modern terminal interaction

## Customization

### Machine-Local Settings

Settings that must not be committed (work config, private hosts, tokens) go in
files outside the repo. Each is sourced last, so it can override anything
above it, and each is optional:

| File | Read by | Use it for |
|------|---------|------------|
| `~/.shell_local` | sh, bash, zsh (POSIX syntax) | Environment and PATH shared by all POSIX shells |
| `~/.bashrc_local` | interactive bash | Bash-only aliases, functions, options |
| `~/.zshrc_local` | interactive zsh | Zsh-only aliases, functions, options |
| `~/.config/fish/local.fish` | fish | Fish equivalent of `~/.shell_local` |

`~/.bash_profile_personal` is no longer read; bash prints a reminder if it
exists. Rename it to `~/.bashrc_local`.

### Environment Variables

Set exported variables and PATH entries in `.profile`, which sh, bash and zsh
all read; never in `.bashrc` or `.zshrc`, which only interactive shells run.
Fish cannot read `.profile`, so mirror the change in
`.config/fish/config.fish`.

## Aliases Reference

### Common Aliases
- `ll` - Long listing with human-readable sizes
- `la` - List all files including hidden
- `..`, `...`, `....` - Navigate up directories
- `dev` - Quick navigate to development directory
- `c` - Clear terminal
- `weather` - Get weather for NYC

### Safety Aliases
- `rm='rm -i'` - Interactive remove
- `cp='cp -i'` - Interactive copy
- `mv='mv -i'` - Interactive move

### Development Aliases
- `ec` - Open file in Emacs client
- `gbp <branch>` - Create a git branch and push it with upstream tracking
- `g`, `ga`, `gaa`, `gc`, `gcm`, `gco`, `gd`, `gds`, `gl`, `gp`, `gpl`, `gs`,
  `gst`, `gstp` - Git shortcuts (abbreviations in fish)
- `j` - `jj` (an abbreviation in fish)

### jj Aliases

These are jj's own aliases, defined in `~/.config/jj/conf.d/dotfiles.toml`, so
they work the same in every shell and jj completes them. jj already ships
`st`, `b` (bookmark), `ci` (commit) and `desc` (describe).

| Command | Does | git counterpart |
|---------|------|-----------------|
| `jj bp NAME` | create bookmark `NAME` on your change and push it, tracked | `gbp NAME` |
| `jj l` | one line per change | `gl` |
| `jj push` / `jj fetch` | `jj git push` / `jj git fetch` | `gp` / `gpl` |
| `jj tug` | move the nearest bookmark up to `@-`, i.e. onto what `jj commit` just finished | — |

`jj bp` puts the bookmark on `@` if it has content, otherwise on `@-`, which is
where `jj commit` leaves your work. To override one of these aliases, set it
in a file that sorts later, such as `~/.config/jj/conf.d/zz-local.toml`.

jj completion is generated once with `COMPLETE=<shell> jj` and cached under
`~/.cache/dotfiles`; it is regenerated when the jj binary is newer than the
cache, i.e. after an upgrade.

## VCS Prompt

All three shells (bash, zsh, fish) show the state of the repository you are in.
Which VCS is reported is decided by walking up from the current directory: the
first `.jj` or `.git` found wins, so a colocated repo reports as **jj**.

### Git — rendered in blue as `(branch<markers>)`

| Marker | Meaning |
|--------|---------|
| `+` | staged changes (index differs from HEAD) |
| `*` | unstaged changes (working tree differs from index) |
| `?` | untracked files present |

On a detached HEAD — including `git bisect` and `git worktree add --detach` —
there is no branch name, so the short commit is shown instead: `(@a1b2c3d)`.

### Jujutsu — rendered in magenta as `(bookmark@changeid<markers>)`

| Marker | Meaning |
|--------|---------|
| `*` | working copy is not empty (as of the last snapshot — see below) |
| `!` | the change is conflicted |
| `?` | the change is divergent |

The markers differ from git because the models do. jj has no index, so there is
no staged/unstaged split and no `+`. jj tracks everything in the workspace, so
there is no untracked state either, and `?` is reused for divergent changes.

`bookmark` is the nearest bookmark in the ancestry, not a "current branch" — jj
has no such concept, and the working copy `@` usually carries no bookmark at
all. When there is none anywhere above you, the prompt shows just `(@changeid)`.

**Snapshot accuracy.** The prompt runs jj with `--ignore-working-copy`. Without
that flag, every prompt render would snapshot the working copy, writing a
`snapshot working copy` entry to the operation log and running roughly 5x
slower. The trade-off is that `*` reflects the last snapshot rather than this
instant; it catches up the next time any jj command runs. Set
`DOTFILES_JJ_SNAPSHOT=1` to get an always-accurate marker at the cost of
mutating the repo on every prompt.

**Colocated repos fall back to git.** If jj is missing, fails, or is older
than 0.22 (the first release with bookmarks), a repo that has `.git` beside
`.jj` shows the git prompt instead of nothing. A pure jj repo shows nothing:
it does not borrow the prompt of a git repo that happens to enclose it.

**Hardening.** As with git, a repo you merely `cd` into cannot run code
through the prompt:
- The prompt pins `signing.behavior=drop` and `fsmonitor.backend=none`. With
  `DOTFILES_JJ_SNAPSHOT=1` the snapshot writes a commit, and a config that
  forces signing would otherwise run its `signing.backends.*.program`.
- A repo that still has its config at the pre-0.38 location (a regular file
  at `.jj/repo/config.toml`) is skipped. jj 0.38+ would move that file under
  `~/.config/jj/repos/` and trust it from then on, so the prompt leaves that
  step to the first jj command you run there yourself.

## Troubleshooting

### Stow Conflicts
If you get conflicts when running `make link`:
```bash
# Rename the conflicting files to *.bak, then link
make force-link
```

### Checking the Install
```bash
make status
```
Reports, for every file the repo installs, whether it is linked, missing, a
real file in the way, or a link into another tree.

### Missing Dependencies
Install missing tools as needed:
```bash
# macOS
brew install git stow tmux

# Linux (add xsel or wl-clipboard instead of xclip if you prefer)
sudo apt-get install git stow tmux xclip
```

### Tmux Has a Plain Status Bar
The plugins are not installed. Run `make tmux-plugins`, then reload with
`tmux source-file ~/.tmux.conf`.

## License

BSD 3-Clause. See [LICENSE](LICENSE).

## Contributing

Feel free to fork this repository and adapt it to your needs. Pull requests for improvements are welcome!