-- base colorscheme
vim.cmd.colorscheme("cyberdream")

local hl = vim.api.nvim_set_hl

-- custom highlight groups
hl(0, "TrailingWhitespace", { fg = "#eff7fe", bg = "#ea5950" })
vim.fn.matchadd("TrailingWhitespace", [[\s\+$]])
