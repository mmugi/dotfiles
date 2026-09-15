# shellcheck shell=dash

# Dotfiles Deployment Library <deploy.sh>
#
# install と uninstall が共有する部分。configs から manifest を組み立て、配置先の
# 状態を分類し、結果を報告する。配置そのもの (mkdir や ln) は行わない。
#
# * Usage *
#
#   DOTFILES_PATH を設定したうえで source する。
#
#     . "${DOTFILES_PATH}/lib/shell/deploy.sh"
#
# * Input *
#
#   ${DOTFILES_PATH}/configs/<パッケージ名>/<HOMEからの相対パス>
#
#   パッケージは configs 直下のディレクトリのみ。その中はホームからの相対パスを
#   そのまま再現する。
#
# * Output *
#
#   配置対象はタブ区切り5列の manifest として標準出力へ書き出す。
#
#     <pkg>\t<type>\t<relpath>\t<src>\t<dst>
#
#   type は d (実ディレクトリ) か f (それ以外)。src は ln -s に渡す値そのもの。
#   LC_ALL=C で pkg → type → relpath の順に整列するので、パッケージ内では
#   ディレクトリがファイルより先、親が子より先に並ぶ。
#
#   install も uninstall も同じ manifest を見る。除外の判定が1箇所しかないため、
#   両者で判定が食い違うことが起こらない。
#
# * Limitation *
#
#   パスに改行やタブを含む場合は扱えない。タブは manifest の区切りと衝突するため
#   検出して停止する。

# sort の照合順序を環境に依存させない。バイト順で並べることで、manifest の並びと
# 削除時の親子関係がロケールによって変わらなくなる。
LC_ALL=C
export LC_ALL

DEPLOY_TAB=$(printf '\t')

# ---- messaging -------------------------------------------------------------
# 人間向けはすべて stderr に出す。色の判定を [ -t 2 ] 一本にでき、stdout を
# 機械可読な出力に空けられる。

DEPLOY_C_OK=''
DEPLOY_C_WARN=''
DEPLOY_C_ERR=''
DEPLOY_C_DIM=''
DEPLOY_C_RST=''

if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  DEPLOY_C_OK=$(printf '\033[32m')
  DEPLOY_C_WARN=$(printf '\033[33m')
  DEPLOY_C_ERR=$(printf '\033[31m')
  DEPLOY_C_DIM=$(printf '\033[2m')
  DEPLOY_C_RST=$(printf '\033[0m')
fi

deploy_progress() { printf '%s[>]%s %s\n' "$DEPLOY_C_DIM"  "$DEPLOY_C_RST" "$*" >&2; }
deploy_created()  { printf '%s[+]%s %s\n' "$DEPLOY_C_OK"   "$DEPLOY_C_RST" "$*" >&2; }
deploy_removed()  { printf '%s[-]%s %s\n' "$DEPLOY_C_OK"   "$DEPLOY_C_RST" "$*" >&2; }
deploy_skipped()  { printf '%s[=]%s %s\n' "$DEPLOY_C_DIM"  "$DEPLOY_C_RST" "$*" >&2; }
deploy_warn()     { printf '%s[!]%s %s\n' "$DEPLOY_C_WARN" "$DEPLOY_C_RST" "$*" >&2; }
deploy_error()    { printf '%s[x]%s %s\n' "$DEPLOY_C_ERR"  "$DEPLOY_C_RST" "$*" >&2; }
deploy_detail()   { printf '    %s\n' "$*" >&2; }

deploy_announce() {
  # usage: deploy_announce <動作> <パッケージ>
  # manifest は pkg 順に整列済みで同じパッケージのアナウンスは連続するため、直前に出して
  # いた場合は出さない。
  if [ "${DEPLOY_ANNOUNCED:-}" != "$2" ]; then
    deploy_progress "${1} ${2}..."
    DEPLOY_ANNOUNCED="$2"
  fi
}

deploy_die() {
  deploy_error "$@"
  exit 1
}

deploy_tilde() {
  # 表示用にホームディレクトリを ~ に縮める。
  case "$1" in
    "$HOME"/*) printf '~%s\n' "${1#"$HOME"}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# ---- environment -----------------------------------------------------------

deploy_init() {
  # usage: deploy_init
  #  - 環境の検証
  #  - ライブラリで利用する変数を構成
  #  - 一時ディレクトリ作成
  #  - 一時ディレクトリ削除用シグナルトラップを登録

  if [ -z "${DOTFILES_PATH:-}" ]; then
    deploy_die 'DOTFILES_PATH is not set'
  fi
  if [ -z "${HOME:-}" ]; then
    deploy_die 'HOME is not set'
  fi

  DEPLOY_CONFIG_DIR="${DOTFILES_PATH}/configs"
  DEPLOY_IGNOREFILE="${DOTFILES_IGNOREFILE:-${DOTFILES_PATH}/.dotignore}"

  readonly DEPLOY_CONFIG_DIR
  readonly DEPLOY_IGNOREFILE

  if [ ! -d "$DEPLOY_CONFIG_DIR" ]; then
    deploy_die "configs directory not found: ${DEPLOY_CONFIG_DIR}"
  fi

  # タブを含むパスがあると manifest の列がずれる。configs が満たすべき前提なので
  # ここで確かめる。deploy_build_manifest は値を標準出力へ返す関数なので、
  # そちらに置くとパイプの段に置かれたときに die が効かない。
  if [ -n "$(find "$DEPLOY_CONFIG_DIR" -mindepth 1 -name "*${DEPLOY_TAB}*" | head -n 1)" ]; then
    deploy_die 'a path under configs contains a tab, which is not supported'
  fi

  # 後始末の登録を mktemp より先に行う。逆にすると、一時ディレクトリが存在するのに
  # 後始末が登録されていない一瞬ができる。
  #
  # EXIT だけでは足りない。dash はシグナルで終了するとき EXIT トラップを実行せず、
  # 一時ディレクトリが残る (実測: dash に TERM を送ると残る。bash は実行するので
  # この差は dash でしか出ない)。INT/TERM/HUP も登録する。
  #
  # ハンドラは trap を解除してから自分へ投げ直す。後始末だけして戻ると終了コードが
  # 0 になり、中断されたのに呼び出し元からは成功に見える。投げ直すことで 128+signo
  # が戻る (実測: 再送なし 0 / 再送あり TERM 143, INT 130)。
  DEPLOY_TMPDIR=''
  trap 'deploy_cleanup' EXIT
  trap 'deploy_cleanup; trap - INT;  kill -INT  $$' INT
  trap 'deploy_cleanup; trap - TERM; kill -TERM $$' TERM
  trap 'deploy_cleanup; trap - HUP;  kill -HUP  $$' HUP

  DEPLOY_TMPDIR=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-XXXXXX") \
    || deploy_die 'failed to create a temporary directory'

  readonly DEPLOY_TMPDIR
}

deploy_cleanup() {
  # rm -rf を呼ぶ前に、消す対象が自分で作った一時ディレクトリであることを確かめる。
  case "${DEPLOY_TMPDIR:-}" in
    */dotfiles-?*) ;;
    *) return 0 ;;
  esac

  # 実体のディレクトリのときだけ消す。すり替えられていたら触らない。
  if [ -d "$DEPLOY_TMPDIR" ] && [ ! -L "$DEPLOY_TMPDIR" ]; then
    rm -rf -- "$DEPLOY_TMPDIR"
  fi
}

deploy_require_tmpfile() {
  # usage: deploy_require_tmpfile <出力先>
  #
  # 書き出し先が自分の一時ディレクトリの直下であることを確かめる。
  # 中身のあるファイルは受け付けない。これから埋める空の作業ファイルだけを通す。
  # 万一パスを取り違えても、既にあるものを消さずに済む。

  case "${DEPLOY_TMPDIR:-}" in
    */dotfiles-?*) ;;
    *) deploy_die 'internal error: the temporary directory is not ready' ;;
  esac

  # 引用した変数は case のパターンでは glob にならず、そのまま前方一致になる。
  case "$1" in
    "${DEPLOY_TMPDIR}"/?*) ;;
    *) deploy_die "internal error: refusing to write outside ${DEPLOY_TMPDIR}: $1" ;;
  esac

  # 前方一致は通っても .. でたどれば外へ出られる。
  case "$1" in
    */../* | */..) deploy_die "internal error: invalid output path: $1" ;;
  esac

  if [ -s "$1" ]; then
    deploy_die "internal error: refusing to overwrite a non-empty file: $1"
  fi
}

# ---- ignore ----------------------------------------------------------------

deploy_is_junk() {
  # usage: deploy_is_junk <ファイル名>
  # どの環境でも配置対象にしないもの。増やすときはこの case に足す。

  # パターンを変数にまとめて for で回す形は採らない。`for p in $VAR` はリストが
  # パス名展開を受けるため、カレントディレクトリに *.swp があるだけで
  # パターンがそのファイル名に化ける (実測)。set -f で止められるが、
  # case のパターンに変数を展開する形は shellcheck の SC2254 になる。
  case "$1" in
    .DS_Store | *.swp | *~) return 0 ;;
  esac
  return 1
}

deploy_is_ignored() {
  # usage: deploy_is_ignored <HOMEからの相対パス>
  #
  # .dotignore の各行をリテラルの前方一致パターンとして評価する。
  # 空行と # から始まる行は無視する。
  #
  # エントリごとにファイルを読み直しているが、対象は数十件で中身も数行なので
  # 実測できる差にはならない。パターンを変数に持つと語分割とグロブの抑制が
  # 必要になり、そちらのほうが壊れやすい。

  local ign_rel ign_pat
  ign_rel="$1"

  if [ ! -s "$DEPLOY_IGNOREFILE" ]; then
    return 1
  fi

  while IFS= read -r ign_pat || [ -n "$ign_pat" ]; do
    case "$ign_pat" in
      '' | '#'*) continue ;;
    esac
    case "$ign_rel" in
      "$ign_pat"*) return 0 ;;
    esac
  done < "$DEPLOY_IGNOREFILE"

  return 1
}

# ---- manifest --------------------------------------------------------------

deploy_build_manifest() {
  # usage: deploy_build_manifest
  # manifest を標準出力へ書き出す。.dotignore の除外の報告は標準エラーに出力。

  local src entry pkg rel type

  # find に sort を通すのは除外の報告を毎回同じ順で出すため。manifest の並びは
  # 後段の sort が決めるので、こちらには依存しない。
  find "$DEPLOY_CONFIG_DIR" -mindepth 2 | sort | while IFS= read -r src; do
    if deploy_is_junk "${src##*/}"; then
      continue
    fi

    # configs/<パッケージ>/<HOMEからの相対パス> から pkg, rel を切り出す。
    entry="${src#"${DEPLOY_CONFIG_DIR}"/}"
    pkg="${entry%%/*}"
    rel="${entry#*/}"

    # ディレクトリへのシンボリックリンクを d と数えない。d にすると中身の
    # 無いディレクトリが配置先に作られる。
    if [ -d "$src" ] && [ ! -L "$src" ]; then
      type=d
    else
      type=f
    fi

    if deploy_is_ignored "$rel"; then
      # ディレクトリは入れ物でしかないので報告しない。中身が全部除外されたなら
      # そのディレクトリはそもそも作らないし、残るなら中のファイルが個別に出る。
      if [ "$type" = f ]; then
        deploy_skipped "ignored: $(deploy_tilde "${HOME}/${rel}")"
      fi

      continue
    fi

    printf '%s\t%s\t%s\t%s\t%s\n' "$pkg" "$type" "$rel" "$src" "${HOME}/${rel}"
  done | sort | awk -F'\t' '
    # ファイルを持たないディレクトリ行と、配置先が重複したディレクトリ行を落とす。

    # 判定に全行が要るので END でまとめて出す。
    { lines[NR] = $0 }

    # ファイルの属する親ディレクトリを記録
    $2 == "f" {
      d = $5
      while (sub(/\/[^\/]*$/, "", d)) {
        if (d in needed_dirs) break
        needed_dirs[d] = 1
      }
    }

    END {
      for (line_no = 1; line_no <= NR; line_no++) {
        split(lines[line_no], fields, "\t")
        if (fields[2] == "d") {
          dst = fields[5]
          if (!(dst in needed_dirs)) continue
          if (dst in printed_dirs) continue
          printed_dirs[dst] = 1
        }
        print lines[line_no]
      }
    }
  '
}


# ---- classification --------------------------------------------------------

deploy_classify() {
  # usage: deploy_classify <type> <src> <dst>
  # 戻り値で配置先の状態を返す。install と uninstall で共用する。
  #
  #   0  未配置
  #   1  src を指すシンボリックリンク (自分が作ったもの)
  #   2  既存のディレクトリで、src もディレクトリ
  #   3  壊れたシンボリックリンク
  #   4  別の場所を指すシンボリックリンク
  #   5  種別が食い違う (ファイルを置く先がディレクトリ、またはその逆)
  #   6  dotfiles の管理外にある実ファイル
  #
  # 自分のものかどうかは readlink の出力と src の文字列比較だけで決める。
  # realpath や readlink -f は古い macOS に無いため使わない。
  #
  # そのため dotfiles を別の場所へ移したあとに削除すると、リンク先の文字列が
  # 変わっていて 4 (別の場所を指すリンク) と判断され、消されずに警告が出る。
  # 配置したときと同じ DOTFILES_PATH で削除すること。

  local cls_type cls_src cls_dst
  cls_type="$1"
  cls_src="$2"
  cls_dst="$3"

  if [ ! -e "$cls_dst" ] && [ ! -L "$cls_dst" ]; then
    return 0
  fi

  if [ -L "$cls_dst" ]; then
    [ "$(readlink "$cls_dst")" = "$cls_src" ] && return 1
    [ ! -e "$cls_dst" ] && return 3
    return 4
  fi

  if [ -d "$cls_dst" ]; then
    [ "$cls_type" = d ] && return 2
    return 5
  fi

  if [ "$cls_type" = d ]; then
    return 5
  fi

  return 6
}

deploy_describe_state() {
  # usage: deploy_describe_state <分類> <dst>

  local state_shown
  state_shown=$(deploy_tilde "$2")
  case "$1" in
    3) printf 'broken symbolic link: %s\n' "$state_shown" ;;
    4) printf 'symbolic link not owned by dotfiles: %s\n' "$state_shown" ;;
    5)
      if [ -d "$2" ]; then
        printf 'expected a file but found a directory: %s\n' "$state_shown"
      else
        printf 'expected a directory but found a file: %s\n' "$state_shown"
      fi
      ;;
    6) printf 'file not owned by dotfiles: %s\n' "$state_shown" ;;
    *) printf 'unexpected state: %s\n' "$state_shown" ;;
  esac
}
