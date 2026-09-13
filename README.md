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
| `.zshenv` | Zsh environment variables and PATH settings |
| `.bash_profile` | Bash login shell configuration |
| `.tmux.conf` | Tmux terminal multiplexer configuration |
| `.gitignore` | Files to ignore in this repository |
| `.profile` | POSIX shell profile |
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

## Git Integration

Both bash and zsh prompts show git information:
- Current branch name
- `*` indicates uncommitted changes
- `+` indicates untracked files

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