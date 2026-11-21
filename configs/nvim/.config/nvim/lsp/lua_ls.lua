-- runtimepath で見つかった <root>/lua/mmerr から <root> を取り出す。
local mmerr_path = vim.fs.dirname(vim.fs.dirname(vim.api.nvim_get_runtime_file("lua/mmerr", false)[1]))

return {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = { ".luarc.json", ".git" },
  settings = {
    Lua = {
      runtime = { version = "LuaJIT", path = { "lua/?.lua", "lua/?/init.lua" } },
      workspace = { library = { vim.env.VIMRUNTIME, mmerr_path } },
      hint = { enable = true },
    },
  },
}
