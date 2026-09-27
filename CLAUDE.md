# Branch Workflow

- `trunk` はいつでも使えるクリーンな状態を保つ。直接コミットしない。
- `trunk` へマージできるのは `dev` と `hotfix/*` からのみ。PR を必ず経由する。
- `dev` は恒久ブランチ。通常の編集作業はここで行う。
- PR のマージ後も `dev` を削除しない。
  GitHub の「Automatically delete head branches」は無効にしておくこと。
- 通常の PR マージ後に `trunk` を `dev` へ取り込まない。`dev` が遅れて見えるのは
  マージコミットの分だけで内容の差ではないため、取り込んでも履歴が汚れるだけ。
- 取り込むのは `hotfix/*` を `trunk` にマージしたときだけ。このときも
  fast-forward のみとし（`git merge --ff-only`）、マージコミットは作らない。
- ff できない場合は `dev` 側を直す。`git rebase` で `dev` を `trunk` の上に
  載せ直し、コンフリクトも `dev` 側で解消する。`dev` は push 済みのため、
  載せ直したあとの push は `--force-with-lease` を使う。

Claude への指示:

- 担当はコミットまで。`git push` は実行しない。指示された場合も実行しない。
  内容を確認したうえで push するのは利用者の作業とする。
- PR は明示的に指示されたときだけ `gh pr create` で作成する。指示がなければ文面を
  用意するまでにとどめる。push は利用者が済ませたあとに実行する。
- `trunk` に直接コミットしない。作業ブランチが `trunk` の場合は先に確認する。
