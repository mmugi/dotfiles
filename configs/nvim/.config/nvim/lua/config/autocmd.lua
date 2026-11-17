-- :set でのオンオフの切り替えを全ウィンドウ共通で覚えておく。
-- WinLeave, WinEnter で更新するので記録しておかないとデフォルト値に書き戻ってしまう。
local shared_cursor_options = {
  cursorcolumn = vim.go.cursorcolumn,
  cursorline = vim.go.cursorline,
}

vim.api.nvim_create_autocmd("OptionSet", {
  pattern = { "cursorcolumn", "cursorline" },
  callback = function(args)
    if vim.v.option_type == "global" then
      shared_cursor_options[args.match] = vim.v.option_new
    end
  end,
})

vim.api.nvim_create_autocmd("WinLeave", {
  callback = function()
    vim.opt_local.cursorcolumn = false
    vim.opt_local.cursorline = false
  end,
})

vim.api.nvim_create_autocmd("WinEnter", {
  callback = function()
    vim.opt_local.cursorcolumn = shared_cursor_options.cursorcolumn
    vim.opt_local.cursorline = shared_cursor_options.cursorline
  end,
})

local function update_hl_trailing_whitespace()
  -- initialize pattern matching
  if vim.w.hl_trailing_whitespace_match_id then
    pcall(vim.fn.matchdelete, vim.w.hl_trailing_whitespace_match_id)
    vim.w.hl_trailing_whitespace_match_id = nil
  end

  -- normal file buffer only
  if vim.bo.buftype == "" then
    vim.w.hl_trailing_whitespace_match_id =
      vim.fn.matchadd("ErrTrailingWhitespace", [[\s\+$]])
  end
end

vim.api.nvim_create_autocmd({
  "BufEnter",
  "BufWinEnter",
  "WinEnter",
  "TermOpen",
}, {
  callback = update_hl_trailing_whitespace,
})

local function update_hl_visual_match()
  if vim.w.hl_visual_match_id then
    pcall(vim.fn.matchdelete, vim.w.hl_visual_match_id)
    vim.w.hl_visual_match_id = nil
  end

  -- 1行に収まる選択だけをハイライト。行跨ぎを許す場合、選択の大きさだけパターン
  -- が大きくなってしまう。
  local mode = vim.fn.mode()
  if not mode:match("^[vV]$") or vim.fn.line("v") ~= vim.fn.line(".") then
    return
  end

  local text = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })[1]
  if not text:match("%S") then
    return
  end

  vim.w.hl_visual_match_id =
    vim.fn.matchadd("VisualMatch", [[\V\c]] .. vim.fn.escape(text, [[\]]))
end

vim.api.nvim_create_autocmd({ "CursorMoved", "ModeChanged" }, {
  callback = update_hl_visual_match,
})
