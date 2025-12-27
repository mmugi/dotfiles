# shellcheck shell=bash
# shellcheck disable=SC2034
{
  LIB_VERSION='1.0.0'
  LIB_DEPS=( esc msg )
  [[ "${1:-}" = '__META_PROBE__' ]] && return 0
}

# shellcheck disable=SC2034
{
  DOTFILES_GREET_COLOR="$ESC_C_BASE"
  DOTFILES_LOGO="$(cat <<LOGO
 _____  _______ _______ _______ _______ _____   _______ _______
|     \|       |_     _|    ___|_     _|     |_|    ___|     __|
|  --  |   -   | |   | |    ___|_|   |_|       |    ___|__     |
|_____/|_______| |___| |___|   |_______|_______|_______|_______|
LOGO
)"
  DOTFILES_LOGO_WIDTH="$(\
    printf '%s\n' "$DOTFILES_LOGO" \
    | awk '{ if (length > max) max = length } END { print max }'
  )"

  readonly DOTFILES_CONFIG_DIR="${DOTFILES_PATH:?}/configs"
  readonly DOTFILES_GITHOOKS_DIR="${DOTFILES_PATH:?}/misc/git/hooks/dotfiles"
  readonly DOTFILES_LOGO_WIDTH
}
