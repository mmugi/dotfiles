# dotfiles

Personal dotfiles, the scripts that organize and deploy them, and assorted helpers.

## Installation

Set `DOTFILES_PATH` to where the dotfiles should live, then install them:

```shell
export DOTFILES_PATH="${HOME}/.dotfiles"
curl https://raw.githubusercontent.com/mmugi/dotfiles/HEAD/install.sh | sh
```

The script downloads this repository there if it is missing, then creates symlinks in your home directory to the files under `configs/`. Missing intermediate directories are created with permission `700`. A directory that would end up empty is not created.

Every destination is checked before anything is deployed. If one is already occupied, the installation reports it and stops without touching your files.

Keep `DOTFILES_PATH` exported in your shell configuration. `uninstall.sh` and the scripts under `scripts/` fail when it is not set.

### > Usage

#### Options

Both `install.sh` and `uninstall.sh` take the same options:

| Option | Description |
| --- | --- |
| `-n`, `--dry-run` | Report what would happen without changing anything. |
| `-v`, `--verbose` | Also report the paths that were left untouched, and why. |
| `-h`, `--help` | Show the usage. |

By default only the paths that actually changed are reported. `--verbose` adds the ones that were skipped, such as a directory that already exists or a file excluded by `.dotignore`.

#### Environment Variables

| Variable | Description |
| --- | --- |
| `DOTFILES_PATH` | Where the dotfiles live. Required. |
| `DOTFILES_BRANCH` | Which branch to download (e.g. `dev`). Defaults to `trunk`. Only used when the repository is not there yet. |
| `DOTFILES_IGNOREFILE` | Where the ignore list lives. Defaults to `${DOTFILES_PATH}/.dotignore`. |

#### Ignoring Configuration Files

List the paths to skip in `.dotignore` in your dotfiles directory:

```plaintext
# vim
.vimrc

.config/git/ignore

# everything under this directory
.config/nvim/
```

Each line is a literal prefix of the path relative to your home directory. `.` and `*` have no special meaning, and `.vim` also matches `.vimrc`, so end a directory with `/`.

Blank lines and lines starting with `#` are ignored.

### > Enabling Configuration Files

Some deployed configuration files are not read by anything on their own. They take effect only once the tool's main configuration file includes them. To use one, run its target below to add that include:

| Target | Appends to |
| --- | --- |
| `make shell-enable TARGET_SHELL=bash` | `~/.bashrc` |
| `make shell-enable TARGET_SHELL=zsh` | `~/.zshrc` |
| `make git-enable` | The global git config, usually `~/.gitconfig` |

## Uninstallation

To remove the installed dotfiles:

```shell
"${DOTFILES_PATH}/uninstall.sh"
```

This removes the symlinks that the install process created, along with any directories left empty afterwards. The configuration files themselves live in this repository and are not deleted.

Uninstall with the same `DOTFILES_PATH` that was used to install. If this repository has moved, the old links are reported instead of removed.

Anything that is not a symlink owned by this repository is left untouched and reported with a warning.

## Configuration Layout

Configuration files live under `configs/`, one directory per package. Within a package, files are laid out exactly as they should appear relative to your home directory:

```plaintext
configs
├── git
│   └── .config
│       └── git
│           └── config
└── vim
    └── .vimrc
```

## Assorted Scripts

The scripts under `scripts/` handle everything other than deploying. `make` runs them and lists what is available:

```shell
cd "$DOTFILES_PATH" && make help
```
