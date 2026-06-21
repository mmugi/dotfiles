# shellcheck shell=bash

LIB_VERSION='1.0.0'
LIB_DEPS=()
[[ "${1:-}" = '__IMPORT__' ]] && return 0

# shellcheck disable=SC2034
{
  # shellcheck disable=SC2155
  declare -gr DOTFILES_LOGO="$(cat <<LOGO
 _____  _______ _______ _______ _______ _____   _______ _______
|     \|       |_     _|    ___|_     _|     |_|    ___|     __|
|  --  |   -   | |   | |    ___|_|   |_|       |    ___|__     |
|_____/|_______| |___| |___|   |_______|_______|_______|_______|
LOGO
  )"

  # shellcheck disable=SC2155
  declare -gr DOTFILES_LOGO_UNINSTALL="$(cat <<LOGO
 _______ _______ _______ _______ _______ _______ _______ _____   _____
|   |   |    |  |_     _|    |  |     __|_     _|   _   |     |_|     |_
|   |   |       |_|   |_|       |__     | |   | |       |       |       |
|_______|__|____|_______|__|____|_______| |___| |___|___|_______|_______|

LOGO
  )"

  declare -g DOTFILES_CONFIG_DIR="${DOTFILES_PATH:?}/configs"
  declare -g DOTFILES_GITHOOKS_DIR="${DOTFILES_PATH:?}/misc/git/hooks/dotfiles"
  declare -g DOTFILES_BREWFILE_DIR="${DOTFILES_PATH:?}/misc/brew"
}
