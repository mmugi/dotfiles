# dotfiles

## Installation

### > One-Line Install

Install the dotfiles with a single command:

```shell
bash -c "$(curl -fsSL https://raw.githubusercontent.com/mmugi/dotfiles/HEAD/bootstrap.sh)"
```

### > Install via Git

Alternatively, clone the repository and run the installation using `make`:

```shell
git clone git@github.com:mmugi/dotfiles.git ~/.dotfiles
export DOTFILES_PATH="${HOME}/.dotfiles"
cd ~/.dotfiles && make install
```

Add the same `export` to your shell config as well, since the `make` targets need it at runtime. The one-line install above sets it for you.

### > Installation Options

#### Environment Variables

You can customize the installation behavior by setting the following environment variables:

| Variable | Description |
| --- | --- |
| `DOTFILES_PATH` | Where the dotfiles live. Defaults to `~/.dotfiles`. The scripts require this at runtime, so export it from your shell config. |
| `DOTFILES_BRANCH` | Which branch to use (e.g. `dev`). Defaults to `trunk`. |
| `DOTFILES_DOWNLOADER` | Which downloader to use (`git`, `curl`, or `wget`). If unset, they are tried in that order. |
| `DOTFILES_PRIVATE_PATH` | Where an optional private overlay repository lives. Defaults to `~/.dotfiles-private`. Ignored when the directory does not exist. |

#### Ignoring Configuration Files

To prevent accidental overwrites, the installation stops when existing configuration files are detected.

If you prefer to keep your existing files, add a `.dotignore` file to your dotfiles directory listing the paths to skip:

```plaintext
# vim
.vimrc

.config/git/ignore
```

Each line in `.dotignore` is matched against the deployment path relative to your home directory, anchored at the beginning. Patterns are treated as regular expressions, so characters such as `.` and `*` have their usual regex meaning.

Blank lines and lines starting with `#` are ignored.

#### Private Overlay

Some configuration is not meant to be published. Keep it in a separate private repository that mirrors the `configs/` layout of this one:

```plaintext
~/.dotfiles-private
└── configs
    └── some-package
        └── .config
            └── example
                └── private.conf
```

When `DOTFILES_PRIVATE_PATH` points at an existing directory, `make install` and `make uninstall` walk its `configs/` alongside this repository's. This repository never references the overlay contents, so it stays publishable on its own and everything still works when the overlay is absent.

The overlay adds files rather than replacing them. If both repositories deploy to the same path, the installation names both sources and stops before deploying anything.

## Uninstallation

To remove the installed dotfiles:

```shell
cd ~/.dotfiles && make uninstall
```

This removes the symlinks that the install process created, along with any directories left empty afterwards. The configuration files themselves live in this repository and are not deleted.

Anything that is not a symlink owned by this repository is left untouched and reported with a warning.

## Help

For the full list of commands:

```shell
cd ~/.dotfiles && make help
```
