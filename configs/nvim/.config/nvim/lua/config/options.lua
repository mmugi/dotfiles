-- :options

-- 2 moving around, searching and patterns
vim.opt.wrapscan = false
vim.opt.ignorecase = true

-- 4 displaying text
-- vim.opt.cmdheight = 0 -- affects message output.
vim.opt.cmdheight = 1
vim.opt.list = true
vim.opt.listchars = {
  extends = '»',
  nbsp = '%',
  precedes = '«',
  tab = '>-',
  trail = '-',
}
vim.opt.number = true

-- 5 syntax, highlighting and spelling
vim.opt.background = "dark"
vim.opt.termguicolors = true
vim.opt.cursorcolumn = true
vim.opt.cursorline = true
vim.opt.cursorlineopt = "number"

-- 6 multiple windows
vim.opt.laststatus = 3
vim.opt.winborder = "rounded"
vim.opt.splitbelow = true
vim.opt.splitright = true

-- 12 selecting text
vim.opt.clipboard:append({ "unnamedplus" })

-- 13 editing text
vim.opt.pumborder = "rounded"

-- 14 tabs and indenting
vim.opt.tabstop = 4
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 0
vim.opt.expandtab = true

-- 20 command line editing
vim.opt.wildmode = "longest,full:noselect"
vim.opt.wildoptions = "pum,fuzzy"
vim.opt.wildmenu = true
vim.opt.cmdwinheight = 15
