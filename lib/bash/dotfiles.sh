# shellcheck shell=bash

# @deps core

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
  declare -g DOTFILES_PRIVATE_PATH="${DOTFILES_PRIVATE_PATH:-${HOME}/.me}"
  declare -g DOTFILES_PRIVATE_CONFIG_DIR="${DOTFILES_PRIVATE_PATH}/configs"
  declare -g DOTFILES_RUNTIME_DIR="${DOTFILES_PATH:?}/run"
  declare -g DOTFILES_GITHOOKS_DIR="${DOTFILES_PATH:?}/misc/git/hooks/dotfiles"
  declare -g DOTFILES_BREWFILE_DIR="${DOTFILES_PATH:?}/misc/brew"
  declare -g DOTFILES_IGNOREFILE="${DOTFILES_PATH:?}/.dotignore"
}

dotfiles::config_dirs() {
  # usage: dotfiles::config_dirs
  #
  # コンフィグのパッケージを探索するルートディレクトリを1行ずつ出力する。
  #
  # 公開リポジトリの configs に加え、DOTFILES_PRIVATE_PATH が存在すればその
  # configs も対象にする。公開したくない設定をプライベートリポジトリに置いた
  # まま、配置の仕組みだけをこちらで持つための拡張点。プライベート側が無い
  # 環境では黙って公開分だけを返すため、単体でも成立する。
  #
  # プライベート側は追加であって上書きではない。両者が同じ配置先を指した場合、
  # util::install が「dotfiles の管理下にないリンク」として衝突を報告する。
  #
  # install と uninstall の両方が同じ集合を見る必要があるため、ここに置いている。

  printf '%s\n' "${DOTFILES_CONFIG_DIR:?}"

  if [[ -d "${DOTFILES_PRIVATE_CONFIG_DIR:-}" ]]; then
    printf '%s\n' "$DOTFILES_PRIVATE_CONFIG_DIR"
  fi
}

dotfiles::is_ignored() {
  # usage: dotfiles::is_ignored <config_relpath_from_home>
  #
  # 引数のパスが DOTFILES_IGNOREFILE (.dotignore) で除外されているかを判定する。
  # 引数はホームディレクトリからの相対パスで指定する。
  #
  # .dotignore の各行は行頭にアンカーした正規表現として評価される。
  # 空行と # から始まる行は無視する。
  #
  # install と uninstall の両方から参照するため、ここに置いている。
  # 除外されたパスは dotfiles の管理外として、配置も解除も行わない。

  if (( $# != 1 )); then
    core::error 'usage: dotfiles::is_ignored <config_relpath_from_home>'
    return 1
  fi

  local relpath="$1"
  local pattern

  [[ -s "$DOTFILES_IGNOREFILE" ]] || return 1

  while read -r pattern; do
    [[ -z "$pattern" || "$pattern" =~ ^# ]] && continue
    [[ "$relpath" =~ ^$pattern ]] && return 0
  done < "$DOTFILES_IGNOREFILE"

  return 1
}
