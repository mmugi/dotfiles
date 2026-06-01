local icon_enabled = true
local cursor_info = false
local mode = false

return {
  "b0o/incline.nvim",
  event = "VeryLazy",
  dependencies = {
    { "nvim-mini/mini.icons", opts = {} }
  },
  opts = {
    window = {
      padding = 0,
      placement = {
        horizontal = "right",
        vertical = "top",
      },
      width = "fit",
    },
  },
  config = function(_, opts)
    vim.opt.laststatus = 0
    vim.opt.statusline = "─"
    vim.opt.fillchars = { stl = "─", stlnc = "─" }
    vim.opt.ruler = false
    vim.opt.showcmd = false
    vim.opt.showmode = false
    vim.api.nvim_set_hl(0, "StatusLine", { link = "WinSeparator" })

    local _, mini_icons = pcall(require, "mini.icons")
    local function get_icon(filepath)
      if not icon_enabled or not _G.MiniIcons then -- checking if mini.icons is loaded
        return nil, nil
      end

      local filestat = vim.uv.fs_stat(filepath)
      if not filestat or filestat.type ~= "file" then
        return nil, nil
      end

      local filename = vim.fn.fnamemodify(filepath, ":t")
      return mini_icons.get(filestat.type, filename)
    end

    local function get_cursor_info(props)
      if not cursor_info then
        return nil
      end

      local cursor = vim.api.nvim_win_get_cursor(props.win)
      local row = cursor[1]
      local col = cursor[2] + 1
      local total_lines = vim.fn.line("$")

      return string.format(
        " [%d/%d:%d]",
        row,
        col,
        total_lines
      )
    end

    local function get_mode(props)
      if not mode then
        return nil
      end

      local focused = props.focused
      local mode = vim.fn.mode()
      local mode_text = nil
      local hl_group = nil

      if mode:match("^i") and focused then
        mode_text = " <<INSERT"
        hl_group = "InclineInsert"
      elseif mode:match("[vV\22]") and focused then
        local wc = vim.fn.wordcount()
        mode_text = string.format(
          " <<VISUAL %d lines, %d chars",
          math.abs(vim.fn.line("v") - vim.fn.line(".")) + 1,
          wc.visual_chars or 0
        )
        hl_group = "InclineVisual"
      end

      return mode_text, hl_group
    end

    opts.render = function(props)
      local filepath = vim.api.nvim_buf_get_name(props.buf)
      local filename = vim.fn.fnamemodify(filepath, ":t")

      filename = filename == "" and "[No Name]" or filename

      local icon, icon_hl = get_icon(filepath)
      local modified = vim.bo[props.buf].modified
      local cursor_info = get_cursor_info(props)
      local mode, mode_hl = get_mode(props)

      return {
        icon and { " ", icon, group = icon_hl } or "",
        { " ", filename, gui = modified and "italic" or "" },
        modified and { "*", group = "InclineModified" } or "",
        cursor_info and { cursor_info, group = "LineNr" } or "",
        mode and { mode, group = mode_hl } or "",
      }
    end

    require("incline").setup(opts)
  end,
}
