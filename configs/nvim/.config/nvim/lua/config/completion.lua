local autocomplete_off_group = vim.api.nvim_create_augroup("autocomplete_off", { clear = true })
local prose_filetypes = { "markdown", "text", "gitcommit" }
vim.api.nvim_create_autocmd("FileType", {
  group = autocomplete_off_group,
  callback = function(args)
    if vim.bo[args.buf].buftype ~= "" then
      return
    end
    if vim.tbl_contains(prose_filetypes, args.match) then
      vim.opt_local.autocomplete = false
    else
      vim.cmd("set autocomplete<")
    end
  end,
})
-- :enew や起動直後の、名前も filetype もないバッファ。
vim.api.nvim_create_autocmd("BufEnter", {
  group = autocomplete_off_group,
  callback = function()
    if vim.bo.buftype == "" and vim.bo.filetype == "" and vim.api.nvim_buf_get_name(0) == "" then
      vim.opt_local.autocomplete = false
    end
  end,
})

-- コマンドラインモードで打つたびに wildmenu を出し直すことでインクリメンタルに補完する。
-- <c-e> で閉じるか <c-y> で確定したら、次に <tab> を押すまで止める。
-- ディレクトリを確定したときは止めずに、その中身を出す。
local cmdline_autocomplete_enabled = true
local tab = vim.keycode("<tab>")
local close = vim.keycode("<c-e>")
local accept = vim.keycode("<c-y>")
vim.on_key(function(key)
  if vim.fn.getcmdtype() ~= ":" then
    return
  end
  if key == tab then
    cmdline_autocomplete_enabled = true
  elseif (key == close or key == accept) and vim.fn.wildmenumode() == 1 then
    local info = vim.fn.cmdcomplete_info()
    local selected = info.matches[info.selected + 1]
    if key == accept and selected and selected:match("[/\\]$") then
      vim.schedule(vim.fn.wildtrigger)
    else
      cmdline_autocomplete_enabled = false
    end
  end
end, vim.api.nvim_create_namespace("cmdline_autocomplete"))

local cmdline_autocomplete_group = vim.api.nvim_create_augroup("cmdline_autocomplete", { clear = true })
vim.api.nvim_create_autocmd("CmdlineChanged", {
  group = cmdline_autocomplete_group,
  pattern = ":",
  callback = function()
    if cmdline_autocomplete_enabled then
      vim.fn.wildtrigger()
    end
  end,
})
vim.api.nvim_create_autocmd("CmdlineLeave", {
  group = cmdline_autocomplete_group,
  callback = function()
    cmdline_autocomplete_enabled = true
  end,
})
