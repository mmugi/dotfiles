local autocomplete_off_group = vim.api.nvim_create_augroup("autocomplete_off", { clear = true })
local prose_filetypes = { "markdown", "text", "gitcommit" }
vim.api.nvim_create_autocmd("FileType", {
  group = autocomplete_off_group,
  callback = function(args)
    if vim.bo[args.buf].buftype ~= "" then
      return
    end
    if vim.tbl_contains(prose_filetypes, args.match) then
      vim.opt_local.autocomplete = false
    else
      vim.cmd("set autocomplete<")
    end
  end,
})
-- :enew や起動直後の、名前も filetype もないバッファ。
vim.api.nvim_create_autocmd("BufEnter", {
  group = autocomplete_off_group,
  callback = function()
    if vim.bo.buftype == "" and vim.bo.filetype == "" and vim.api.nvim_buf_get_name(0) == "" then
      vim.opt_local.autocomplete = false
    end
  end,
})
-- 一部の単語の入力中は自動補完をオフにする。
--   - ASCII 以外が入る単語:
--       日本語は単語の区切りを判定しづらく、入力も確定するまで反映されないためオフにする。
--       vim.lsp は \k で置き換えの範囲を決めるので、日本語にくっついた英数字で補完すると
--       日本語ごと書き換わってしまう場合がある。そのため前後を含めて \k の範囲に ASCII 以外
--       が含まれるかチェックする。
--   - 数字だけの単語
local non_ascii = "[^\1-\127]"
vim.api.nvim_create_autocmd("InsertCharPre", {
  group = autocomplete_off_group,
  callback = function()
    if vim.bo.buftype ~= "" then
      return
    end
    local line = vim.api.nvim_get_current_line()
    local col = vim.fn.col(".")
    local keyword = vim.fn.matchstr(line:sub(1, col - 1), [[\k*$]])
      .. vim.v.char
      .. vim.fn.matchstr(line:sub(col), [[^\k*]])
    if keyword:find(non_ascii) or keyword:find("^%d+$") then
      if vim.bo.autocomplete == nil then
        vim.opt_local.autocomplete = false
        vim.b.autocomplete_paused = true
      end
    elseif vim.b.autocomplete_paused then
      vim.cmd("set autocomplete<")
      vim.b.autocomplete_paused = nil
    end
  end,
})

-- LSP の候補は vim.fn.complete() で届き、そこからはバッファの単語を集め直さない。
-- LSP の候補が全部外れると、何も出ないまま補完が続くので、止めて <c-n> で集め直す。
-- <c-e> は補完が終わったあとに届くと下の行の文字を入れるので、文字を変えない <c-x><c-z> で止める。
vim.api.nvim_create_autocmd("TextChangedI", {
  group = vim.api.nvim_create_augroup("lsp_completion_empty", { clear = true }),
  callback = function()
    if vim.fn.complete_info({ "mode" }).mode == "eval" and vim.fn.pumvisible() == 0 then
      local restart = vim.o.autocomplete and "<c-n>" or ""
      vim.api.nvim_feedkeys(vim.keycode("<c-x><c-z>" .. restart), "n", false)
    end
  end,
})

-- LSP の候補を優先させるための比較関数。
-- cmp を渡すと既定の並べ替えが止まるので、LSP 同士は既定を参考に _fuzzy_score 順にする。
-- _fuzzy_score は vim.lsp の内部用のフィールド。使えなくなった場合 sortText 順になる。
local function compare_completion(a, b)
  local lsp_item_a = vim.tbl_get(a, "user_data", "nvim", "lsp", "completion_item")
  local lsp_item_b = vim.tbl_get(b, "user_data", "nvim", "lsp", "completion_item")
  if (lsp_item_a == nil) ~= (lsp_item_b == nil) then
    return lsp_item_a ~= nil
  end
  -- a,b どちらも LSP の候補ではない場合
  if not lsp_item_a then
    return a.word < b.word
  end
  local score_a, score_b = a._fuzzy_score or 0, b._fuzzy_score or 0
  if score_a ~= score_b then
    return score_a > score_b
  end
  return (lsp_item_a.sortText or lsp_item_a.label) < (lsp_item_b.sortText or lsp_item_b.label)
end

-- vim.lsp は LSP の候補に dup = 1 を付けるので、バッファの単語と同じ単語が重複して並ぶ。
-- dup = 0 にして先に並んでいるほうを残して重複を捨てる。
-- compare_completion で LSP の候補を優先させるため、重複した場合 LSP の候補が残る。
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("lsp_completion_dedup", { clear = true }),
  callback = function(args)
    vim.lsp.completion.enable(true, args.data.client_id, args.buf, {
      convert = function()
        return { dup = 0 }
      end,
      cmp = compare_completion,
    })
  end,
})

-- 補完のプレビューポップアップは nvim が内部でフローティングウィンドウで作っているため、
-- 現状枠がつかず、'winborder' などのオプションから制御できない。
-- nvim__complete_set は内部用の API のため、nvim の更新で壊れる可能性あり。
local complete_set = vim.api.nvim__complete_set
vim.api.nvim__complete_set = function(...)
  local result = complete_set(...)
  if result and result.winid and vim.o.winborder ~= "" then
    pcall(vim.api.nvim_win_set_config, result.winid, { border = vim.o.winborder })
  end
  return result
end

-- コマンドラインモードで打つたびに wildmenu を出し直すことでインクリメンタルに補完する。
-- <c-e> で閉じるか <c-y> で確定したら、次に <tab> を押すまで止める。
-- ディレクトリを確定したときは止めずに、その中身を出す。
local cmdline_autocomplete_enabled = true
local tab = vim.keycode("<tab>")
local close = vim.keycode("<c-e>")
local accept = vim.keycode("<c-y>")
vim.on_key(function(key)
  if vim.fn.getcmdtype() ~= ":" then
    return
  end
  if key == tab then
    cmdline_autocomplete_enabled = true
  elseif (key == close or key == accept) and vim.fn.wildmenumode() == 1 then
    local info = vim.fn.cmdcomplete_info()
    local selected = info.matches[info.selected + 1]
    if key == accept and selected and selected:match("[/\\]$") then
      vim.schedule(vim.fn.wildtrigger)
    else
      cmdline_autocomplete_enabled = false
    end
  end
end, vim.api.nvim_create_namespace("cmdline_autocomplete"))

local cmdline_autocomplete_group = vim.api.nvim_create_augroup("cmdline_autocomplete", { clear = true })
vim.api.nvim_create_autocmd("CmdlineChanged", {
  group = cmdline_autocomplete_group,
  pattern = ":",
  callback = function()
    if cmdline_autocomplete_enabled then
      vim.fn.wildtrigger()
    end
  end,
})
vim.api.nvim_create_autocmd("CmdlineLeave", {
  group = cmdline_autocomplete_group,
  callback = function()
    cmdline_autocomplete_enabled = true
  end,
})
