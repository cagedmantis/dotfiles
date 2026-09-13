# Dotfiles

Personal shell configuration files and environment settings for macOS/Linux development environments.

## Overview

This repository contains my personal dotfiles including shell configurations (bash/zsh), terminal multiplexer settings (tmux), and various development environment configurations. The setup is optimized for software development with features like git-aware prompts, modern shell options, and convenient aliases.

## Features

### Shell Configuration
- **Bash**: Enhanced history, safety aliases, git-aware prompt, OS-specific configurations
- **Zsh**: Modern shell options, auto-completion, directory navigation shortcuts, git integration
- **Cross-platform**: Works on macOS, Linux, and Cygwin

### Terminal Multiplexer
- **Tmux**: Custom key bindings, enhanced status bar, optimized for development workflows

### Development Tools Integration
- Git completion and branch information in prompts
- Docker shortcuts and utilities
- Node.js (nvm), Ruby (rvm), Rust, Python (virtualenv) support
- Google Cloud SDK integration
- Kubernetes (kubectl) completion

## Installation

### Prerequisites

- Git
- GNU Stow

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
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

2. Create symlinks using GNU Stow:
```bash
make link
```

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
# Create symlinks manually
stow --target=$HOME .
```

#### Adopt Existing Files
If you have existing dotfiles you want to replace:
```bash
make adopt
```

## Configuration Files

| File | Purpose |
|------|---------|
| `.bashrc` | Bash shell configuration, aliases, and functions |
| `.zshrc` | Zsh shell configuration with modern features |
| `.zshenv` | Zsh, every invocation; dedupes PATH and sources `.profile` |
| `.bash_profile` | Bash login shell; sources `.profile` then `.bashrc` |
| `.tmux.conf` | Tmux terminal multiplexer configuration |
| `.gitignore` | Files to ignore in this repository |
| `.profile` | POSIX base: PATH, EDITOR/VISUAL and exported env, shared by sh, bash and zsh |
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
- **Performance optimized**: Fast startup with efficient plugin loading

### Tmux Configuration
- **Custom prefix**: `Ctrl-g` (better for Emacs users)
- **Intuitive bindings**: `|` for horizontal split, `-` for vertical split
- **Enhanced status bar**: Shows session, user, and system information
- **Mouse support**: Enabled for modern terminal interaction

## Customization

### Adding Personal Configurations

The configurations support loading additional personal files:

**Bash:**
- `~/.bash_profile_ps` - PostScript/work-specific settings
- `~/.bash_profile_do` - DigitalOcean-specific settings  
- `~/.bash_profile_personal` - Personal settings
- `~/.bash_linux` - Linux-specific settings
- `~/.bash_osx` - macOS-specific settings

**Zsh:**
You can add custom configurations at the end of `.zshrc` or create separate files and source them.

### Environment Variables

Set environment variables in:
- `.zshenv` (for zsh)
- `.bash_profile` (for bash)

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
- `tmux='tmux -2'` - Force 256 color mode
- `ec` - Open file in Emacs client
- `gbp` - Git branch and push function

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

## Troubleshooting

### Stow Conflicts
If you get conflicts when running `make link`:
```bash
# Backup existing files and adopt them
make adopt
```

### Permission Issues
Ensure proper permissions:
```bash
chmod 600 ~/.bashrc ~/.zshrc
```

### Missing Dependencies
Install missing tools as needed:
```bash
# macOS
brew install git stow tmux

# Linux
sudo apt-get install git stow tmux
```

## License

Licensed under the BSD License. See the repository for full license details.

## Contributing

Feel free to fork this repository and adapt it to your needs. Pull requests for improvements are welcome!