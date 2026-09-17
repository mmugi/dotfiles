# dotfiles

Personal dotfiles, the scripts that organize and deploy them, and assorted helpers.

## Installation

Set `DOTFILES_PATH` to where the dotfiles should live, then install them:

```shell
export DOTFILES_PATH="${HOME}/.dotfiles"
curl https://raw.githubusercontent.com/mmugi/dotfiles/HEAD/install.sh | sh
```

The script downloads this repository into that directory when it is not there yet, then deploys everything.

### > Configuration Layout

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

`install.sh` walks every package and deploys each entry to the matching path under your home directory. Regular files become symlinks back into this repository, so editing a deployed file edits the file here. Missing intermediate directories are created with permission `700`. A directory that would end up holding nothing is not created at all.

Every package is checked before anything is deployed. If a destination is already occupied, the installation reports it and stops without touching your files.

### > Installation Options

#### Command Line

Both `install.sh` and `uninstall.sh` take the same flags:

| Flag | Description |
| --- | --- |
| `-n`, `--dry-run` | Report what would happen without changing anything. |
| `-v`, `--verbose` | Also report the paths that were left untouched, and why. |
| `-h`, `--help` | Show the usage. |

By default only the paths that actually changed are reported. `--verbose` adds the ones that were skipped, such as a directory that already exists or a file excluded by `.dotignore`.

#### Exit Status

| Status | Meaning |
| --- | --- |
| `0` | Finished with nothing left to do. |
| `1` | Stopped before touching anything: bad usage, missing `DOTFILES_PATH`, or a conflict found during the check. |
| `2` | Ran, but something was left behind: a path that could not be placed, or one that is not owned by this repository. |

#### Environment Variables

You can customize the installation behavior by setting the following environment variables:

| Variable | Description |
| --- | --- |
| `DOTFILES_PATH` | Where the dotfiles live. **Required**; there is no default. |
| `DOTFILES_BRANCH` | Which branch to download (e.g. `dev`). Defaults to `trunk`. Only used when the repository is not there yet. |
| `DOTFILES_DOWNLOADER` | Which downloader to use (`git`, `curl`, or `wget`). If unset, they are tried in that order. |
| `DOTFILES_IGNOREFILE` | Where the ignore list lives. Defaults to `${DOTFILES_PATH}/.dotignore`. |

#### Ignoring Configuration Files

If you prefer to keep your existing files, add a `.dotignore` file to your dotfiles directory listing the paths to skip:

```plaintext
# vim
.vimrc

.config/git/ignore

# everything under this directory
.config/nvim/
```

Each line is matched literally against the deployment path relative to your home directory, anchored at the beginning, so `.` and `*` have no special meaning. It is a plain prefix: `.vim` would also match `.vimrc`, so add a trailing `/` when you mean a directory.

Blank lines and lines starting with `#` are ignored.

## Uninstallation

To remove the installed dotfiles:

```shell
"${DOTFILES_PATH}/uninstall.sh"
```

This removes the symlinks that the install process created, along with any directories left empty afterwards. The configuration files themselves live in this repository and are not deleted.

**Uninstall with the same `DOTFILES_PATH` that was used to install.** Ownership is decided by comparing the symlink target against the path this repository would deploy, so after moving this repository elsewhere the old links are no longer seen as owned by it and are reported instead of removed.

Anything that is not a symlink owned by this repository is left untouched and reported with a warning.

## Assorted Scripts

The scripts under `scripts/` handle everything other than deploying. `make` wraps them for convenience, and lists what is available:

```shell
cd "$DOTFILES_PATH" && make help
```
