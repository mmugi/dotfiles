vim.lsp.enable({ "lua_ls", "bashls" })

vim.diagnostic.config({
  severity_sort = true,
  virtual_lines = { current_line = true },
})
