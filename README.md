# dotfiles

## Installation

### > One-Line Install

Install the dotfiles with a single command:

```shell
curl -fsSL https://raw.githubusercontent.com/mmugi/dotfiles/HEAD/install.sh | DOTFILES_PATH="${HOME}/.dotfiles" sh
```

`DOTFILES_PATH` is required and must be set on `sh`, not on `curl`. The script downloads this repository into that directory when it is not there yet, then deploys everything.

### > Install via Git

Alternatively, clone the repository and run the installation using `make`:

```shell
git clone git@github.com:mmugi/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && make install
```

`make` passes its own location as `DOTFILES_PATH`, so nothing needs to be exported for it. Running the scripts directly does require it:

```shell
DOTFILES_PATH="${HOME}/.dotfiles" ~/.dotfiles/install.sh
```

The scripts are POSIX-ish `sh` and do not depend on the `bash` libraries in this repository, so they run on a stock macOS or a minimal Linux without installing anything first.

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

`make install` walks every package and deploys each entry to the matching path under your home directory. Regular files become symlinks back into this repository, so editing a deployed file edits the file here. Missing intermediate directories are created with permission `700`. A directory that would end up holding nothing is not created at all.

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
| `128`+ | Interrupted by a signal. |

`1` and `2` are kept apart so that a caller can tell "nothing happened, safe to retry" from "partially applied".

#### Environment Variables

You can customize the installation behavior by setting the following environment variables:

| Variable | Description |
| --- | --- |
| `DOTFILES_PATH` | Where the dotfiles live. **Required**; there is no default. |
| `DOTFILES_BRANCH` | Which branch to download (e.g. `dev`). Defaults to `trunk`. Only used when the repository is not there yet. |
| `DOTFILES_DOWNLOADER` | Which downloader to use (`git`, `curl`, or `wget`). If unset, they are tried in that order. |
| `DOTFILES_IGNOREFILE` | Where the ignore list lives. Defaults to `${DOTFILES_PATH}/.dotignore`. |
| `NO_COLOR` | Set to anything to drop the colors. They are also dropped when the output is not a terminal. |

#### Ignoring Configuration Files

To prevent accidental overwrites, the installation stops when existing configuration files are detected.

If you prefer to keep your existing files, add a `.dotignore` file to your dotfiles directory listing the paths to skip:

```plaintext
# vim
.vimrc

.config/git/ignore

# everything under this directory
.config/nvim/
```

Each line is matched literally against the deployment path relative to your home directory, anchored at the beginning. Nothing is treated as a pattern, so `.` and `*` have no special meaning.

Because the match is a plain prefix, `.vim` also excludes `.vimrc`. Add a trailing `/` when you mean the directory and everything below it.

Blank lines and lines starting with `#` are ignored. `.DS_Store`, `*.swp` and `*~` are always skipped and are never reported.

### > Limitations

Paths containing a tab or a newline are not supported. A tab collides with the column separator used internally, and is reported before anything is deployed.

## Uninstallation

To remove the installed dotfiles:

```shell
cd ~/.dotfiles && make uninstall
```

This removes the symlinks that the install process created, along with any directories left empty afterwards. The configuration files themselves live in this repository and are not deleted.

Ownership is decided by comparing the symlink target against the path this repository would deploy. **Uninstall with the same `DOTFILES_PATH` that was used to install.** After moving this repository elsewhere the targets no longer match, so the old links are treated as somebody else's and are reported instead of removed.

Anything that is not a symlink owned by this repository is left untouched and reported with a warning.

## Help

For the full list of commands:

```shell
cd ~/.dotfiles && make help
```
