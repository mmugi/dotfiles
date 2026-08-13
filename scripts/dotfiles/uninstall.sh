#!/usr/bin/env bash

set -ueo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_PATH}/lib/bash/import.sh"
import log theme dotfiles msg util shellconf

theme::load
msg::init

exec_user="$(whoami)"
if [[ "$exec_user" == 'root' ]]; then
  logger --fatal "don't run this script as root:<"
  exit 1
fi

if [[ ! -t 0 ]]; then
  logger --fatal 'stdin is not connected to a tty'
  exit 1
fi

DOTFILES_UNINSTALL_DRYRUN=0

# 集計用
#   警告が出ても処理を止めず、最後にまとめて確認できるようにする。
declare -a UNINSTALL_REMOVED=()
declare -a UNINSTALL_WARNED=()
declare -a UNINSTALL_IGNORED=()

case "${1:-notset}" in
  --dryrun) DOTFILES_UNINSTALL_DRYRUN=1 ;;
  notset) :;;
  *)
    logger --fatal "invalid option: $1"
    exit 1
    ;;
esac

greet() {
  local date greet_msg

  date="$(date '+%Y/%m/%d %H:%M:%S %Z')"
  greet_msg="$(cat <<EOF
<@noprompt><@hl style="danger"><@b>
${DOTFILES_LOGO_UNINSTALL}
</@noprompt></@hl></@b>
<@br>
hello:)
this is the dotfiles uninstallation script.
date: ${date}
dotfiles path: <hl>${DOTFILES_PATH}</hl>
EOF
  )"

  msg::box -- "$greet_msg"
  msg::newline
}

_uninstall_target() {
  # usage: _uninstall_target src target relpath
  #
  # util::uninstall をモードに応じて呼び分け、結果を集計する。
  # 警告時に1を返すため、呼び出し側は if で受けて set -e を回避する。

  local src="$1" target="$2" relpath="$3"
  local rc=0

  # 対象が存在しない場合、util::uninstall は「何もすることがない」として0を
  # 返す。それを削除予定として数えないよう、ここで先に除外する。
  if [[ ! -e "$target" && ! -L "$target" ]]; then
    logger --debug "target does not exist: ${target}"
    return 0
  fi

  # .dotignore で除外されたパスは install が配置していないので、解除もしない。
  # ユーザー自身のファイルが置かれているだけなので、警告ではなくスキップとして
  # 扱う。残っているものが見えるように、集計して summary には出す。
  if dotfiles::is_ignored "$relpath"; then
    msg::skipped "ignored by .dotignore: ${target}"
    UNINSTALL_IGNORED+=( "$target" )
    return 0
  fi

  if (( DOTFILES_UNINSTALL_DRYRUN )); then
    util::uninstall --dry-run "$src" "$target" || rc=$?
  else
    util::uninstall "$src" "$target" || rc=$?
  fi

  if (( rc == 0 )); then
    UNINSTALL_REMOVED+=( "$target" )
  else
    UNINSTALL_WARNED+=( "$target" )
  fi

  return 0
}

_summary_body() {
  # summaryの中身を組み立てる。
  # msg::rm / msg::skipped などの既存フォーマットをそのまま使い、
  # 出力を msg::box --box-rendered に渡して枠で囲む。

  local target

  msg --no-prompt --base-style='msg_header' -- '🚀 summary'
  msg::newline

  if (( ${#UNINSTALL_REMOVED[@]} > 0 )); then
    if (( DOTFILES_UNINSTALL_DRYRUN )); then
      msg::rm "${#UNINSTALL_REMOVED[@]} symbolic link(s) to be removed:"
    else
      msg::rm "${#UNINSTALL_REMOVED[@]} symbolic link(s) removed:"
    fi
    for target in "${UNINSTALL_REMOVED[@]}"; do
      msg --no-prompt --indent 5 -- "${target/#"${HOME}"/\~}"
    done
  else
    msg::skipped 'no symbolic links to remove.'
  fi

  if (( ${#UNINSTALL_IGNORED[@]} > 0 )); then
    msg::newline
    msg::skipped "${#UNINSTALL_IGNORED[@]} path(s) ignored by .dotignore:"
    for target in "${UNINSTALL_IGNORED[@]}"; do
      msg --no-prompt --indent 5 -- "${target/#"${HOME}"/\~}"
    done
  fi

  msg::newline

  if (( ${#UNINSTALL_WARNED[@]} > 0 )); then
    msg::warning "${#UNINSTALL_WARNED[@]} file(s) left in place:"
    for target in "${UNINSTALL_WARNED[@]}"; do
      msg --no-prompt --indent 5 -- "${target/#"${HOME}"/\~}"
    done
    msg::newline
    msg::notice 'see the warnings above for the reason.'
    msg::notice 'these need to be handled manually.'
  else
    msg::ok 'no warnings:)'
  fi

  # 完了通知もこのboxに含める。
  #   - dry-run: 何も削除していないので出さない
  #   - 警告あり: 残ったものがあるので「完了」と言い切らない。
  #               対応方法は上の notice で案内している
  if (( ! DOTFILES_UNINSTALL_DRYRUN && ${#UNINSTALL_WARNED[@]} == 0 )); then
    msg::newline
    msg --no-prompt --base-style='success' -- '🛸 DOTFILES UNINSTALLATION COMPLETED'
  fi
}

print_summary() {
  # 末尾に空行は入れない。dry-runではこれが最後の出力になり、
  # 空行で終わるとプロンプトとの間隔が他のスクリプトと揃わなくなる。
  # 後続の出力がある場合は呼び出し側で区切りを入れる。
  msg::box --box-rendered -- "$(_summary_body)"
}

uninstall_configs() {
  local pkg_dirs pkg_dir pkg_name config_relpath_fromhome config_dir

  if [[ -z "${DOTFILES_CONFIG_DIR:-}" ]]; then
    logger --fatal 'DOTFILES_CONFIG_DIR is not set'
    exit 1
  fi

  # install と同じ集合を見る。プライベートリポジトリが存在すれば
  # そちらが配置したリンクも解除の対象になる。
  pkg_dirs="$(
    while read -r config_dir; do
      find "$config_dir" -mindepth 1 -maxdepth 1 -type d
    done < <(dotfiles::config_dirs)
  )"

  if [[ -z "$pkg_dirs" ]]; then
    msg::warning "package directories not found:/"
    return 0
  fi

  # install と同様、同じパッケージ名が複数の探索ルートに存在しうるため、
  # 見出しはパッケージ名でまとめる。
  local pkg_names
  pkg_names="$(while read -r pkg_dir; do basename -- "$pkg_dir"; done <<<"$pkg_dirs" | sort -u)"

  while read -r pkg_name; do
    msg "removing <hl>${pkg_name}</hl> configs..."

    while read -r pkg_dir; do
      [[ "$(basename -- "$pkg_dir")" == "$pkg_name" ]] || continue

      if [[ ! -d "$pkg_dir" ]]; then
        logger --fatal "directory not found: ${pkg_dir}"
        exit 1
      fi

      local src_files src_dirs
      local src_file src_dir target

      src_files="$(find "$pkg_dir" -mindepth 1 -type f)"
      src_dirs="$(
        find "$pkg_dir" -mindepth 1 -type d \
          | awk '{ print gsub("/", "/"), $0 }' \
          | sort -nr \
          | cut -d ' ' -f 2
      )"

      if [[ -z "$src_files" && -z "$src_dirs" ]]; then
        continue
      fi

      # シンボリックリンクの削除
      if [[ -n "$src_files" ]]; then
        while read -r src_file; do
          config_relpath_fromhome="${src_file#"${pkg_dir}/"}"
          target="${HOME}/${config_relpath_fromhome}"
          logger --debug "remove target config file: ${target}"

          _uninstall_target "$src_file" "$target" "$config_relpath_fromhome"
        done <<<"$src_files"
      fi

      # 空のディレクトリを削除
      if [[ -n "$src_dirs" ]]; then
        while read -r src_dir; do
          target="${HOME}/${src_dir#"${pkg_dir}/"}"
          logger --debug "remove target dir: ${target}"

          if [[ ! -d "$target" ]]; then
            logger --debug "target dir is not exists: ${target}"
            continue
          fi

          if [[ -z "$(ls -A "$target")" ]]; then
            logger --debug "dir is empty: ${target}"
            if (( ! DOTFILES_UNINSTALL_DRYRUN )); then
              # 削除できなくても他のコンフィグの処理は続ける
              if ! rmdir -- "$target" 2>/dev/null; then
                msg::warning "failed to remove directory: ${target}"
                UNINSTALL_WARNED+=( "$target" )
                continue
              fi
            fi
            msg::rm "directory deleted: $target"
          else
            logger --debug "dir is not empty: ${target}"
          fi
        done < <(echo "$src_dirs")
      fi
    done <<<"$pkg_dirs"
  done <<<"$pkg_names"
}

uninstall_shell_configs() {
  # シェル設定は configs/ の walk に乗らないため、install と同じ固定テーブルを
  # 見て個別に解除する。生成物 (run/ 配下) 自体は消さない。再生成できるうえ、
  # git 管理外なので残っていても害がない。

  local src relpath target dstdir

  msg 'removing shell configs...'

  while IFS=$'\t' read -r src relpath; do
    target="${HOME}/${relpath}"
    logger --debug "remove target shell config: ${target}"

    _uninstall_target "$src" "$target" "$relpath"
  done < <(shellconf::outputs)

  # 空になった配置先ディレクトリを片付ける。install がこれらを作るため、
  # 解除もこちらで責任を持つ。深い順に見て、空でなければ触らない
  # (~/.config/fish/conf.d に利用者のファイルが残っている場合など)。
  while read -r dstdir; do
    [[ -d "$dstdir" ]] || continue
    [[ -z "$(ls -A "$dstdir")" ]] || continue

    if (( ! DOTFILES_UNINSTALL_DRYRUN )); then
      if ! rmdir -- "$dstdir" 2>/dev/null; then
        msg::warning "failed to remove directory: ${dstdir}"
        UNINSTALL_WARNED+=( "$dstdir" )
        continue
      fi
    fi
    msg::rm "directory deleted: ${dstdir}"
  done < <(
    shellconf::outputs \
      | cut -f2 \
      | while IFS= read -r relpath; do printf '%s/%s\n' "$HOME" "${relpath%/*}"; done \
      | awk '{ print gsub("/", "/"), $0 }' \
      | sort -nru \
      | cut -d ' ' -f 2-
  )

  return 0
}

greet

if (( DOTFILES_UNINSTALL_DRYRUN )); then
  msg::notice 'dry-run mode is enabled.'
  msg::notice \
    'empty directories resulting from configuration removal will be removed,' \
    'but will not be shown in dry-run mode.'
fi

if msg::confirm; then
  uninstall_configs
  uninstall_shell_configs

  # 警告がある場合、boxは完了を言い切らない (COMPLETED を出さない) ため、
  # 結論はこの行で示す。
  if (( ${#UNINSTALL_WARNED[@]} > 0 )); then
    msg::warning 'finished with warnings:/'
  else
    msg::ok 'configuration files uninstalled:)'
  fi
  msg::newline

  print_summary
  # 別れの挨拶は、きれいに終わったときだけ。
  # dry-run と警告ありは COMPLETED と同じ条件で抑制する。
  if (( ! DOTFILES_UNINSTALL_DRYRUN && ${#UNINSTALL_WARNED[@]} == 0 )); then
    msg::newline
    msg 'goodbye👋'
  fi
else
  msg::newline
  msg::box --prompt='👾' --base-style='abort' -- 'UNINSTALLATION ABORTED'
  exit 1
fi
