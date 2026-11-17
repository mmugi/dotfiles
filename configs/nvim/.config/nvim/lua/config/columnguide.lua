local ns_id = vim.api.nvim_create_namespace("columnguide")

local config = {
  columns = { 80, 100 },
  char = "│",
  highlights = {
    ColumnGuide = { link = "NonText", default = true },
  },
}

local function set_highlights()
  for name, opts in pairs(config.highlights) do
    vim.api.nvim_set_hl(0, name, opts)
  end
end

-- colorscheme が読み込み時に hi clear する場合、デフォルトのハイライトグループ
-- が消えるので autocmd で設定し直す。
set_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_highlights })

vim.api.nvim_set_decoration_provider(ns_id, {
  on_win = function(_, _, buf_id)
    return vim.bo[buf_id].buftype == ""
  end,
  on_line = function(_, win_id, buf_id, row)
    local width = vim.fn.virtcol({ row + 1, "$" }, false, win_id) - 1

    for _, column in ipairs(config.columns) do
      -- 文字に重なる行には描かない
      if width < column then
        vim.api.nvim_buf_set_extmark(buf_id, ns_id, row, 0, {
          virt_text = { { config.char, "ColumnGuide" } },
          virt_text_pos = "overlay",
          virt_text_win_col = column - 1,
          hl_mode = "combine",
          ephemeral = true,
        })
      end
    end
  end,
})
