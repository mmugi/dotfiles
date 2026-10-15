local M = {}

M.default_options = {
  transparent_bg = false,
  terminal_colors = true,
  highlight_overrides = {},
  palette_overrides = {},
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
  local palette = vim.tbl_extend("force", require("mmerr.palette"), M.options.palette_overrides)
  local groups = require("mmerr.groups").setup(palette)

  vim.opt.background = "dark"
  vim.cmd("highlight clear")
  vim.opt.termguicolors = true
  vim.g.colors_name = "mmerr"

  -- set highlight bg to nil of TRANSPARENT_HIGHLIGHT_GROUPS
  if M.options.transparent_bg then
    for _, v in ipairs(TRANSPARENT_HIGHLIGHT_GROUPS) do
      groups[v].bg = nil
    end
  end

  -- override highlight groups
  if type(M.options.highlight_overrides) == "table" then
    override_groups(groups, M.options.highlight_overrides)
  elseif type(M.options.highlight_overrides) == "function" then
    override_groups(groups, M.options.highlight_overrides(palette))
  end

  -- apply theme
  for k, v in pairs(groups) do
    vim.api.nvim_set_hl(0, k, v)
  end

  -- set ANSI colors for :terminal
  if M.options.terminal_colors then
    local terminal_colors = {
      palette.black,
      palette.red,
      palette.turquoise,
      palette.yellow,
      palette.blue,
      palette.rose,
      palette.purple,
      palette.white,
      palette.gray,
      palette.amaranth,
      palette.mint,
      palette.yellow,
      palette.sky,
      palette.pink,
      palette.lavender,
      palette.pure_white,
    }
    for i, color in ipairs(terminal_colors) do
      vim.g["terminal_color_" .. (i - 1)] = color
    end
  end
end

return M
