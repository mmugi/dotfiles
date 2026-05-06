local M = {}

M.default_options = {
  transparent_bg = false,
  overrides = {},
}

M.options = vim.deepcopy(M.default_options)

-- groups with a defined bg that should be explicitly set to transparent
local TRANSPARENT_HIGHLIGHT_GROUPS = {
  "Normal",
}

local function override_groups(groups, overrides)
  for group, tbl in pairs(overrides) do
    groups[group] = tbl
  end
  return groups
end

function M.setup(opts)
  -- set user options
  M.options = vim.tbl_deep_extend("force", M.default_options, opts or {})
end

function M.load()
  local palette = require("mmerr.palette")
  local groups = require("mmerr.groups").setup(palette)

  if vim.g.colors_name then
    vim.cmd("highlight clear")
  end

  if vim.fn.exists("syntax_on") then
    vim.cmd("syntax reset")
  end

  vim.opt.background = "dark"
  vim.opt.termguicolors = true
  vim.g.colors_name = "mmerr"

  -- set highlight bg to nil of TRANSPARENT_HIGHLIGHT_GROUPS
  if M.options.transparent_bg then
    for _, v in ipairs(TRANSPARENT_HIGHLIGHT_GROUPS) do
      groups[v].bg = nil
    end
  end

  -- override highlight groups
  if type(M.options.overrides) == "table" then
    override_groups(groups, M.options.overrides)
  elseif type(M.options.overrides) == "function" then
    override_groups(groups, M.options.overrides(palette))
  end

  -- apply theme
  for k, v in pairs(groups) do
    vim.api.nvim_set_hl(0, k, v)
  end
end

return M
