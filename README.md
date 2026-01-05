# dotfiles

## Installation

### > One-Line Install

Install the dotfiles with a single command:


``` shell
bash -c "$(curl -fsSL https://raw.githubusercontent.com/mmugi/dotfiles/HEAD/bootstrap.sh)"
```

### > Install via Git

Alternatively, clone the repository and run the installation using make:

``` shell
git clone git@github.com:mmugi/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && make install
```

### > Installation Options

#### Environment Variables

You can customize the installation behavior by setting the following environment variables:

| Variable | Description |
| --- | --- |
| DOTFILES_BRANCH | Specify which branch to use (e.g., develop). |
| DOTFILES_DOWNLOADER | Choose a downloader (git, curl, or wget). If unset, the installer will try them in that order. |

#### Ignoring Configuration Files

By default, the installation will stop when existing configuration files are detected to prevent accidental overwrites.

If you prefer to keep your existing files and skip overwriting them, add a `.dotignore` file in your dotfiles directory:

``` plaintext
.vimrc
.config/git/ignore
```

Each line in `.dotignore` should be a prefix pattern relative to your home directory.

## Initialization

This repository includes optional initialization tasks intended for one-time system setup.

Initialization tasks are not idempotent.
To prevent accidental execution, they are available **only when the following environment variable is set**:

``` shell
export DOTFILES_INIT=true
make init
```

If `DOTFILES_INIT` is not set, any attempt to run initialization tasks will fail.

## Uninstallation

To remove the installed dotfiles:

``` shell
cd ~/.dotfiles && make uninstall
```

This will remove the symlinks and any managed config files that were deployed by the install process.

## Help

``` shell
cd ~/.dotfiles && make help
```
