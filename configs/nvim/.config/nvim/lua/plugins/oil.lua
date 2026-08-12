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
    view_options = {
      show_hidden = true,
    },
  },
  dependencies = {
    { "nvim-mini/mini.icons", opts = {} },
    -- "nvim-tree/nvim-web-devicons", -- use if you prefer nvim-web-devicons
  },
  lazy = false,
}
