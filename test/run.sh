#!/usr/bin/env bash
#
# test/ 配下のテストをすべて実行する。
#
#   bash test/run.sh
#
# 各テストファイルは独立したプロセスで動かす。テストファイル同士で変数や関数が
# 干渉しないようにするためと、1つが落ちても残りを最後まで走らせるため。
#
# 個別に走らせたい場合はテストファイルを直接叩けばよい。
#
#   bash test/cli.sh

set -ueo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

declare -i files=0
declare -i failed=0
declare -a failed_names=()

for testfile in "${TEST_DIR}"/*.sh; do
  name="$(basename -- "$testfile")"

  # run.sh 自身と、テストを持たない共通部分は対象外
  case "$name" in
    run.sh | helper.sh) continue ;;
  esac

  files=$(( files + 1 ))
  printf '=== %s ===\n' "${name%.sh}"

  if ! bash "$testfile"; then
    failed=$(( failed + 1 ))
    failed_names+=( "$name" )
  fi

  printf '\n'
done

if (( files == 0 )); then
  printf 'no test files found in %s\n' "$TEST_DIR"
  exit 1
fi

if (( failed )); then
  printf '%d/%d test file(s) failed: %s\n' "$failed" "$files" "${failed_names[*]}"
  exit 1
fi

printf '%d test file(s) passed\n' "$files"
