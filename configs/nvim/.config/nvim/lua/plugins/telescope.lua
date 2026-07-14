--local custom_openers = {
--  man = { command = "tab Man" },
--  help = { command = "tab help" },
--}
--
--local function custom_open(kind)
--  return function(prompt_bufnr)
--    local actions = require("telescope.actions")
--    local actions_state = require("telescope.actions.state")
--
--    local entry = actions_state.get_selected_entry()
--    local opener = custom_openers[kind]
--
--    if not opener then
--      actions.close(prompt_bufnr)
--      error("Unknown telescope opener: " .. tostring(kind))
--    end
--
--    actions.close(prompt_bufnr)
--
--    vim.cmd(opener.command .. " " .. entry.value)
--    vim.cmd.only()
--  end
--end

return {
  "nvim-telescope/telescope.nvim",
  version = "*",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
  },
  keys = {
    { "<leader>ft", "<cmd>Telescope builtin<cr>", desc = "Telescope builtin pickers", mode = "n" },
    { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Telescope live grep", mode = "n" },
    { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Telescope find files", mode = "n" },
    { "<leader>fc", "<cmd>Telescope command_history<cr>", desc = "Telescope command history", mode = "n" },
    { "<leader>fs", "<cmd>Telescope search_history<cr>", desc = "Telescope search history", mode = "n" },
    { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Telescope buffers", mode = "n" },
    { "<leader>fm", "<cmd>Telescope marks<cr>", desc = "Telescope marks", mode = "n" },
    { "<leader>fr", "<cmd>Telescope registers<cr>", desc = "Telescope registers", mode = "n" },
    { "<leader>fM", "<cmd>Telescope man_pages<cr>", desc = "Telescope man pages", mode = "n" },
    { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Telescope help tags", mode = "n" },
  },
  opts = {
    defaults = {
      sorting_strategy = "ascending",
      layout_strategy = "flex",
      layout_config = {
        prompt_position = "top",
        width = 0.9,
        flex = { flip_columns = 165 },
        horizontal = { preview_width = 0.55 },
        vertical = { preview_height = 0.4, mirror = true },
      },
      selection_caret = "",
      entry_prefix = "" ,
      --path_display = {
      --  filename_first = { reverse_directories = false }
      --},
      file_ignore_patterns = { ".git/" },
    },
    pickers = {
      live_grep = { additional_args = { "--follow", "--hidden" } },
      find_files = { follow = true, hidden = true },
      builtin = { previewer = false, theme = "dropdown", use_default_opts = true },
      commands = { theme = "dropdown" },
      command_history = { theme = "dropdown" },
      search_history = { theme = "dropdown" },
      vim_options = { theme = "dropdown" },
      --help_tags = { mappings = { i = { ["<cr>"] = custom_open("help") } } },
      --man_pages = { mappings = { i = { ["<cr>"] = custom_open("man") } } },
      buffers = { select_current = true },
      colorscheme = { enable_preview = true },
      marks = { mark_type = "local" },
      registers = { theme = "dropdown" },
      keymaps = { theme = "dropdown" },
      filetypes = { theme = "dropdown" },
    },
  },
  config = function(_, opts)
    local actions = require("telescope.actions")
    opts.defaults.mappings = {
      n = { ["<esc>"] = require("telescope.actions").close },
      i = {
        ["<esc>"] = require("telescope.actions").close,
        -- emacs like keymaps
        ["<C-f>"] = { "<right>", type = "command" },
        ["<C-b>"] = { "<left>", type = "command" },
        ["<C-a>"] = { "<home>", type = "command" },
        ["<C-e>"] = { "<end>", type = "command" },
        ["<C-k>"] = { "<C-o>D", type = "command" },
      },
    }
    require("telescope").setup(opts)
  end,
}
