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
export DOTFILES_PATH="${HOME}/.dotfiles"
cd ~/.dotfiles && make install
```

Every make target except `help`, `test` and `lint` needs `DOTFILES_PATH`, so add the same `export` to your shell config as well. The one-line install above sets it for you.

### > Installation Options

#### Environment Variables

You can customize the installation behavior by setting the following environment variables:

| Variable | Description |
| --- | --- |
| DOTFILES_PATH | Where the dotfiles live. Defaults to `~/.dotfiles`. The scripts require this at runtime, so export it from your shell config. |
| DOTFILES_BRANCH | Specify which branch to use (e.g., dev). Defaults to `trunk`. |
| DOTFILES_DOWNLOADER | Choose a downloader (git, curl, or wget). If unset, the installer will try them in that order. |

#### Ignoring Configuration Files

By default, the installation will stop when existing configuration files are detected to prevent accidental overwrites.

If you prefer to keep your existing files and skip overwriting them, add a `.dotignore` file in your dotfiles directory:

``` plaintext
# vim
.vimrc

.config/git/ignore
```

Each line in `.dotignore` is matched against the deployment path relative to your home directory, anchored at the beginning. Patterns are treated as regular expressions, so characters such as `.` and `*` carry their regex meaning.

Blank lines and lines starting with `#` are ignored.

## Uninstallation

To remove the installed dotfiles:

``` shell
cd ~/.dotfiles && make uninstall
```

This removes the symlinks that the install process created, along with any directories left empty afterwards. The configuration files themselves live in this repository and are not deleted.

Files that are not symlinks owned by this repository are left untouched and reported as warnings.

## Help

For the full list of available commands:

``` shell
cd ~/.dotfiles && make help
```
