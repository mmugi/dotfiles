return {
  'lewis6991/gitsigns.nvim',
  lazy = false,
  keys = {
    { "<leader>gd", "<cmd>Gitsigns preview_hunk<cr>", mode = "n" },
    { "<leader>gD", "<cmd>Gitsigns diffthis<cr>", mode = "n" },
    { "<leader>gn", "<cmd>Gitsigns next_hunk<cr>", mode = "n" },
    { "<leader>gp", "<cmd>Gitsigns prev_hunk<cr>", mode = "n" },
  },
}
