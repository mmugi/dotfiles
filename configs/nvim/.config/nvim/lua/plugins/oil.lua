return {
  "stevearc/oil.nvim",
  ---@module 'oil'
  ---@type oil.SetupOpts
  opts = {
    keymaps = {
      ['<C-p>'] = {
        'actions.preview',
        opts = { split = 'belowright' },
      },
    },
    float = {
      padding = 5,
      preview_split = "below",
    },
    view_options = {
      show_hidden = true,
    },
  },
  -- opts = {
  --   float = {
  --     border = 0.5,
  --     preview_split = "right",
  --   },
  --   confirmation = {
  --     border = 5,
  --   },
  --   view_options = {
  --     show_hidden = true,
  --   },
  --   override = function(conf)
  --     return conf
  --   end,
  -- },
  -- Optional dependencies
  dependencies = { { "nvim-mini/mini.icons", opts = {} } },
  -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
  -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
  lazy = false,
}
