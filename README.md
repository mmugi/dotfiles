# dotfiles

## Installation

### ▼ One-Liner

``` shell
bash -c "$(curl -fsSL https://raw.githubusercontent.com/mmugi/dotfiles/HEAD/install.sh)"
```

### ▼ Using Git

You can "git clone" this repository to `~/.dotfiles` and run the installation script.

``` shell
git clone git@github.com:mmugi/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && make install
```

### ▼ Installation Options

#### > Environment Variables

You can customize the installation by setting environment variables.

- `DOTFILES_BRANCH`
  - Specify the branch to download.
  - Example:
    - `DOTFILES_BRANCH='develop'`

- `DOTFILES_DOWNLOADER`
  - Choose the downloader for fetching the repository.
  - Available options:
    - git
    - curl
    - wget
  - If not specified, the installer tries git, then curl, and finally wget.
  - Example:
    - `DOTFILES_DOWNLOADER='curl'`

- `DOTFILES_INIT`
  - Control the initialization behavior.
  - If the environment variable has value, the installation will execute the initialization process.
  - The following processes will be executed:
    - Initial configuration of the package manager
    - Modification of OS settings
    - Installation of applications and configuration updates
  - Example:
    - `export DOTFILES_INIT=true && ~/.dotfiles/install.sh`
    - `DOTFILES_INIT=true make install`

#### > Ignoring Configuration Files

You can also control which configuration files are deployed.

By default, the installation will be stopped when configuration files already exists.
If you wish to prioritize existing configuration files, place a .dotignore file at `~/.dotfiles/.dotignore` and list the patterns that match paths relative to your home directory.

Pattern matching is performed using prefix matching. For example, if you specify `.config`, all configuration files under the `.config/` directory will be ignored.

Example `.dotignore` file:

``` shell
$ cat ~/.dotfiles/.dotignore
.bashrc
.config/tmux/
.config/fish/config.fish
```

## Uninstallation

``` shell
cd ~/.dotfiles && make uninstall
```

## Help

``` shell
cd ~/.dotfiles && make help
```
