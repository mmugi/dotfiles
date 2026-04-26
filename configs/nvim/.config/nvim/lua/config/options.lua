-- options

-- 2 moving around, searching and patterns
vim.opt.wrapscan = false
vim.opt.ignorecase = true

-- 4 displaying text
vim.opt.cmdheight = 0
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
vim.opt.cursorline = false
vim.opt.cursorcolumn = true

-- 12 selecting text
vim.opt.clipboard:append({ "unnamedplus" })

-- 14 tabs and indenting
vim.opt.tabstop = 4
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 0
vim.opt.expandtab = true
