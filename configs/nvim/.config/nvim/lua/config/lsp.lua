vim.lsp.enable({ "lua_ls", "bashls" })

vim.diagnostic.config({
  severity_sort = true,
  virtual_lines = { current_line = true },
})

-- カーソル下のシンボルの参照をハイライトする。
local reference_group = vim.api.nvim_create_augroup("lsp_reference_highlight", { clear = true })
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
  group = reference_group,
  callback = function()
    if #vim.lsp.get_clients({ bufnr = 0, method = "textDocument/documentHighlight" }) > 0 then
      vim.lsp.buf.document_highlight()
    end
  end,
})
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "ModeChanged" }, {
  group = reference_group,
  callback = function()
    vim.lsp.buf.clear_references()
  end,
})
