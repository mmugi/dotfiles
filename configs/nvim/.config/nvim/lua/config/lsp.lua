vim.lsp.enable({ "lua_ls", "bashls" })

vim.diagnostic.config({
  severity_sort = true,
  virtual_lines = { current_line = true },
})

-- カーソル下のシンボルの参照をハイライトする。<c-s> で固定/解除する。
local reference_pinned = false

local function highlight_references()
  vim.lsp.buf.clear_references()
  if #vim.lsp.get_clients({ bufnr = 0, method = "textDocument/documentHighlight" }) > 0 then
    vim.lsp.buf.document_highlight()
  end
end

local reference_group = vim.api.nvim_create_augroup("lsp_reference_highlight", { clear = true })
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
  group = reference_group,
  callback = function()
    if not reference_pinned then
      highlight_references()
    end
  end,
})
vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
  group = reference_group,
  callback = function()
    if not reference_pinned then
      vim.lsp.buf.clear_references()
    end
  end,
})

vim.keymap.set("n", "<c-s>", function()
  reference_pinned = not reference_pinned
  highlight_references()
end, { desc = "Pin or unpin the reference highlights" })
