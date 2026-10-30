vim.keymap.set({ 'n', 'x' }, 'c', '"_c')
vim.keymap.set({ 'n', 'x' }, 'C', '"_C')
vim.keymap.set({ 'n', 'x' }, 's', '"_s')
vim.keymap.set({ 'n', 'x' }, 'S', '"_S')
vim.keymap.set({ 'n', 'x' }, 'x', '"_x')
vim.keymap.set({ 'n', 'x' }, 'X', '"_X')
vim.keymap.set('x', 'p', '"_dP')

vim.keymap.set('n', '<leader>n', '<cmd>tabnext<cr>')
vim.keymap.set('n', '<leader>p', '<cmd>tabprevious<cr>')
vim.keymap.set("n", '<leader>bd', '<cmd>enew | bd#<cr>')
vim.keymap.set('n', '<leader><leader>', '<cmd>buffers<cr>')
vim.keymap.set('n', '<esc><esc>', '<cmd>nohlsearch<cr>')

vim.keymap.set('n', '<c-h>', '<cmd>wincmd h<cr>')
vim.keymap.set('n', '<c-j>', '<cmd>wincmd j<cr>')
vim.keymap.set('n', '<c-k>', '<cmd>wincmd k<cr>')
vim.keymap.set('n', '<c-l>', '<cmd>wincmd l<cr>')

-- jl方向にウィンドウがない場合は増減の符号を反転(端のウィンドウは動く境界線が逆になるため)。
local function resize_window(direction)
  local vertical = direction == 'h' or direction == 'l'
  local step = (direction == 'j' or direction == 'l') and 2 or -2
  local has_next = vim.fn.winnr(vertical and 'l' or 'j') ~= vim.fn.winnr()
  vim.cmd(string.format('%sresize %+d', vertical and 'vertical ' or '', has_next and step or -step))
end
for _, direction in ipairs({ 'h', 'j', 'k', 'l' }) do
  vim.keymap.set('n', '<m-' .. direction .. '>', function() resize_window(direction) end)
end

vim.keymap.set('i', '<esc>', function()
  return vim.fn.complete_info({ 'selected' }).selected ~= -1 and '<c-e>' or '<esc>'
end, { expr = true, desc = 'Cancel the selected completion' })
vim.keymap.set('i', '<cr>', function()
  return vim.fn.complete_info({ 'selected' }).selected ~= -1 and '<c-y>' or '<cr>'
end, { expr = true, desc = 'Accept the selected completion without newline' })

vim.keymap.set('c', '<c-w>', '<c-f>', { desc = 'Open command line winodw' })
vim.keymap.set('c', '<c-b>', '<left>', { desc = 'Emacs like left' })
vim.keymap.set('c', '<c-f>', '<right>', { desc = 'Emacs like right' })
vim.keymap.set('c', '<c-a>', '<home>', { desc = 'Emacs like home' })
--vim.keymap.set('c', '<c-e>', '<end>', { desc = 'Emacs like end' })
--vim.keymap.set('c', '<c-h>', '<bs>', { desc = 'Emacs like bs' })
vim.keymap.set('c', '<c-d>', '<del>', { desc = 'Emacs like del' })
vim.keymap.set('c', '<c-k>', function()
  local cmd = vim.fn.getcmdline()
  local pos = vim.fn.getcmdpos()
  vim.fn.setcmdline(string.sub(cmd, 1, pos - 1))
end, { desc = 'Emacs like kill-line' })
