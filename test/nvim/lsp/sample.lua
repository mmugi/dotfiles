-- LSP highlight sample for checking colorschemes (lua_ls).
-- Not meant to be run.
--
-- Open it from inside this repository so that lua_ls finds the project root,
-- and wait until `:checkhealth vim.lsp` lists this buffer.
-- `:Inspect` on any token shows which groups color it, including `@lsp.*`.

-- セマンティックトークン: 開くだけで有効になり、tree-sitter の色の上に重なる
-- 種類ごとのグループ（@lsp.type.parameter.lua など）は :Inspect で見る
local M = {}

-- 参照ハイライト: MAX_COUNT の上で :lua vim.lsp.buf.document_highlight()
-- 宣言と代入は LspReferenceWrite、読むところは LspReferenceRead になる
-- 消すときは :lua vim.lsp.buf.clear_references()
local MAX_COUNT = 3

---@class sample.Item
---@field name string
---@field count integer

-- ホバー: make_item の上でノーマルモードK。NormalFloat・FloatBorder と、説明文の @markup.*
-- 空行がないと、このコメントまでホバーの説明文に入る

---Make an item.
---@param name string
---@param count integer
---@return sample.Item
local function make_item(name, count)
  return { name = name, count = count }
end

---@deprecated Use make_item instead.
function M.old_make_item(name)
  return make_item(name, 1)
end

---@param item sample.Item
function M.describe(item)
  -- 参照ハイライトの Read と Write: label の上で実行すると、代入の行に両方が並ぶ
  local label = item.name .. ": " .. item.count
  if item.count > MAX_COUNT then
    label = label .. " (too many)"
  end
  return label
end

function M:method()
  return self
end

-- 参照ハイライトは文字ではなく変数で探す: この item で実行すると、
-- 名前が同じ M.describe の引数 item は光らない
local item = make_item("apple", 2)

-- インレイヒント: :lua vim.lsp.inlay_hint.enable() で LspInlayHint が出る
-- 引数名（name: など）はリテラルを渡したところだけ、引数の型は定義側に出る
-- シグネチャヘルプ: 挿入モードで make_item( の括弧の中にいるときに <C-s>
-- 補完: 挿入モードで item. の後に <C-x><C-o>。Pmenu・PmenuSel・PmenuMatch
print(M.describe(item), vim.fn.has("nvim"), string.format("%d", MAX_COUNT))

-- ここから下は診断。下線とサインは既定で出る
-- 行末のメッセージ（DiagnosticVirtualText*）は 0.11 から既定でオフなので、
-- :lua vim.diagnostic.config({ virtual_text = true }) で出す
-- 診断のある行で <C-w>d を押すとフロート（DiagnosticFloating*）

-- Warning: 未定義のグローバル
print(undefined_global)

-- Info: 小文字で始まるグローバル変数
lowercase_global = 1

-- Hint: 未使用のローカル。DiagnosticUnnecessary も付く
local unused = 1

-- Warning: 非推奨の関数。DiagnosticDeprecated も付く
-- ローカル関数に @deprecated を付けても lua_ls は診断を出さない
M.old_make_item("banana")

-- Warning: 引数の型違い
make_item(1, 2)

-- コードレンズ（LspCodeLens）は lua_ls では既定でオフで、そのままでは出ない
-- lsp/lua_ls.lua の settings.Lua に codeLens = { enable = true } を足して開き直し、
-- :lua vim.lsp.codelens.enable() を実行すると、関数の定義の上に参照の数が出る

-- Error: 構文エラー。下の解析を壊すので最後に置く
local broken =
