local shown_hunk

local function hunk_at_cursor()
  local lnum = vim.fn.line('.')
  for _, hunk in ipairs(require('gitsigns').get_hunks() or {}) do
    local first = math.max(hunk.added.start, 1)
    if lnum >= first and lnum < first + math.max(hunk.added.count, 1) then
      return hunk.head
    end
  end
end

-- preview_hunk_inline はカーソル移動で消えるため、消去用の autocmd を外して残す。
-- 同じ hunk で押すと閉じ、別の hunk で押すと表示を差し替える。
local function toggle_preview_hunk_inline()
  local preview = require('gitsigns.actions.preview')
  local bufnr = vim.api.nvim_get_current_buf()
  local hunk = hunk_at_cursor()
  if preview.has_preview_inline(bufnr) and hunk == shown_hunk then
    preview.clear_preview_inline(bufnr)
    shown_hunk = nil
    return
  end
  require('gitsigns').preview_hunk_inline(function()
    for _, autocmd in ipairs(vim.api.nvim_get_autocmds({ buffer = bufnr })) do
      if autocmd.desc == 'Clear gitsigns inline preview' then
        vim.api.nvim_del_autocmd(autocmd.id)
      end
    end
    shown_hunk = hunk
  end)
end

return {
  'lewis6991/gitsigns.nvim',
  lazy = false,
  keys = {
    { "<leader>gg", "<cmd>Gitsigns next_hunk<cr>", mode = "n" },
    { "<leader>GG", "<cmd>Gitsigns prev_hunk<cr>", mode = "n" },
    { "<leader>gd", toggle_preview_hunk_inline, mode = "n" },
    { "<leader>ga", "<cmd>Gitsigns stage_hunk<cr>", mode = "n" },
  },
}
