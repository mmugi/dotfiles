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
