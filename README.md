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

`make install` walks every package and deploys each entry to the matching path under your home directory. Regular files become symlinks back into this repository, so editing a deployed file edits the file here. Missing intermediate directories are created with permission `700`.

Every package is checked before anything is deployed. If a destination is already occupied, the installation reports it and stops without touching your files.

### > Installation Options

#### Environment Variables

You can customize the installation behavior by setting the following environment variables:

| Variable | Description |
| --- | --- |
| `DOTFILES_PATH` | Where the dotfiles live. Defaults to `~/.dotfiles`. The scripts require this at runtime, so export it from your shell config. |
| `DOTFILES_BRANCH` | Which branch to use (e.g. `dev`). Defaults to `trunk`. |
| `DOTFILES_DOWNLOADER` | Which downloader to use (`git`, `curl`, or `wget`). If unset, they are tried in that order. |
| `DOTFILES_PRIVATE_PATH` | Where an optional private overlay repository lives. Defaults to `~/.me`. Ignored when the directory does not exist. |

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

Some configuration is not meant to be published. Keep it in a separate private repository whose `configs/` follows the same layout described above.

When `DOTFILES_PRIVATE_PATH` points at an existing directory, `make install` and `make uninstall` walk its `configs/` alongside this repository's. This repository never references the overlay contents, so it stays publishable on its own and everything still works when the overlay is absent.

The overlay adds files rather than replacing them. If both repositories deploy to the same path, the installation names both sources and stops before deploying anything.

## Shell Configuration

Shell configuration is not written per shell by hand. It is generated for every supported shell from a single registry, so adding a tool means writing one small file instead of keeping `bash`, `zsh` and `fish` in sync.

Supported shells are `bash`, `zsh` and `fish`. The target shell is always given explicitly — `$SHELL` is never consulted, so the configuration is correct even when you run `fish` inside `tmux` under a different login shell.

### > Registry

Entries live under `shell/`, split by when they are needed:

```plaintext
shell
├── env.d               # needed outside interactive shells too (PATH and friends)
│   └── 10-homebrew.sh
└── rc.d                # interactive shells only
    └── 50-prompt.sh
```

Files are read in name order, so the numeric prefix decides what runs first. An entry defines up to three things:

```shell
guard='starship'          # optional. wraps the output in a runtime check for this command
shells='bash zsh fish'    # optional. defaults to every supported shell

render() {
  shellconf::eval_init starship
}
```

`render` receives the target shell in `$1` and writes that shell's code to standard output. Helpers cover the common cases:

| Helper | bash / zsh | fish |
| --- | --- | --- |
| `shellconf::eval_init <cmd> [args]` | `eval "$(cmd init bash)"` | `cmd init fish \| source` |
| `shellconf::export <name> <value>` | `export NAME=value` | `set -gx NAME value` |
| `shellconf::path_prepend <dir>` | prepend, skipping duplicates | `fish_add_path -gp` |
| `shellconf::source_if <file>` | source when readable | source when readable |
| `shellconf::raw <line>...` | emitted as is | emitted as is |

Anything else can be written directly with `case "$1" in ... esac`. Each entry is read in a subshell, so entries never collide with each other.

### > Generated Files

`make install` runs `make shell-conf`, which writes one file per shell into `run/` and symlinks them into place:

| Generated | Installed as |
| --- | --- |
| `run/shell/env.bash`, `run/shell/rc.bash` | `~/.config/shell/env.bash`, `~/.config/shell/rc.bash` |
| `run/shell/env.zsh`, `run/shell/rc.zsh` | `~/.config/shell/env.zsh`, `~/.config/shell/rc.zsh` |
| `run/shell/dotfiles.fish` | `~/.config/fish/conf.d/00-dotfiles.fish` |

`run/` is not tracked by git. Generated files embed machine specific paths, such as where `git-prompt.sh` happens to live, so they must not be committed. Because the installed paths are symlinks, regenerating with `make shell-conf` is enough — nothing needs to be installed again.

The `env` files hold environment variables and can be read by non-interactive login shells. The `rc` files read them first, so hooking only the `rc` file is enough for an interactive shell.

### > Hooking It Up

This repository never owns `~/.bashrc` or `~/.zshrc`. They stay yours. The only thing you add by hand is one line:

```shell
[ -r "$HOME/.config/shell/rc.bash" ] && . "$HOME/.config/shell/rc.bash"
```

`make shell-hook TARGET_SHELL=zsh` prints it for another shell. `fish` needs nothing, since `conf.d` is loaded automatically.

The installation reports this only for shells that do not have the hook yet. It looks for the path, not for the exact line, so writing it your own way — `source` instead of `.`, folded into an `if` you already have — is fine. If you never use a shell, add its destination to `.dotignore` and both the installation and the reminder stop for it.

### > Machine Local Configuration

Anything that should not be committed — a credential, a path that only exists on one machine — goes to files this repository never manages. They are read last, so they win:

```plaintext
~/.config/shell/env.local.sh     ~/.config/shell/env.local.fish
~/.config/shell/rc.local.sh      ~/.config/shell/rc.local.fish
```

Configuration that should be versioned but not published goes to the private overlay instead. Its `shell/env.d` and `shell/rc.d` are merged with this repository's by file name, so `~/.me/shell/rc.d/40-private.sh` lands between `30-` and `50-` from here.

### > Without Installing

`make shell-print` writes the configuration to standard output and nothing else, so it can be redirected or piped somewhere this repository is not installed:

```shell
make shell-print TARGET_SHELL=fish
make shell-print TARGET_SHELL=zsh PHASE=env > ~/.config/shell/env.zsh
```

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
