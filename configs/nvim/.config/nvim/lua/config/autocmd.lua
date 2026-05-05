vim.api.nvim_create_autocmd("WinLeave", {
  callback = function()
    vim.opt_local.cursorcolumn = false
  end,
})

vim.api.nvim_create_autocmd("WinEnter", {
  callback = function()
    vim.opt_local.cursorcolumn = true
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
