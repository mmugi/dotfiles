local M = {}

local ns_id = vim.api.nvim_create_namespace("columnguide")

local default_config = {
  columns = { 80, 100 },
  char = "│",
  highlights = {
    ColumnGuide = { link = "NonText", default = true },
  },
}

function M.setup()
  local config = default_config

  for name, opts in pairs(config.highlights) do
    vim.api.nvim_set_hl(0, name, opts)
  end

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
end

return M
