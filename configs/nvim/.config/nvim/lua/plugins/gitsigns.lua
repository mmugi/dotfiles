return {
  'lewis6991/gitsigns.nvim',
  lazy = false,
  keys = {
    { "<leader>gg", "<cmd>Gitsigns next_hunk<cr>", mode = "n" },
    { "<leader>GG", "<cmd>Gitsigns prev_hunk<cr>", mode = "n" },
    { "<leader>gd", "<cmd>Gitsigns preview_hunk_inline<cr>", mode = "n" },
    { "<leader>ga", "<cmd>Gitsigns stage_hunk<cr>", mode = "n" },
  },
}
