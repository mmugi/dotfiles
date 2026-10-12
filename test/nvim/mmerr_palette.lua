-- Show every color in the mmerr palette in a scratch buffer.
-- Usage: :source test/nvim/mmerr_palette.lua

-- 編集中の palette.lua を読み直す
package.loaded["mmerr.palette"] = nil
local palette = require("mmerr.palette")

-- テーブルは順序を持たないので、palette.lua に書かれた順に並べる
local names = {}
for line in io.lines(vim.api.nvim_get_runtime_file("lua/mmerr/palette.lua", false)[1]) do
  names[#names + 1] = line:match("^%s*([%w_]+)%s*=")
end

local buf = vim.api.nvim_create_buf(false, true)
local lines = {}
for _, name in ipairs(names) do
  lines[#lines + 1] = ("%-16s %s  %s  %s"):format(name, palette[name], "        ", "Sample text")
end
vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

local ns = vim.api.nvim_create_namespace("mmerr-palette")
for i, name in ipairs(names) do
  local swatch, text = "MmerrPaletteBg_" .. name, "MmerrPaletteFg_" .. name
  vim.api.nvim_set_hl(0, swatch, { bg = palette[name] })
  vim.api.nvim_set_hl(0, text, { fg = palette[name] })
  local col = #lines[i] - #"Sample text"
  vim.api.nvim_buf_set_extmark(buf, ns, i - 1, col - 10, { end_col = col - 2, hl_group = swatch })
  vim.api.nvim_buf_set_extmark(buf, ns, i - 1, col, { end_col = #lines[i], hl_group = text })
end

vim.cmd.vsplit()
vim.api.nvim_win_set_buf(0, buf)
