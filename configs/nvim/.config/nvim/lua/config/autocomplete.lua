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
