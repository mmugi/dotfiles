local icon_enabled = false

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
        vertical = "bottom",
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

    opts.render = function(props)
      local filepath = vim.api.nvim_buf_get_name(props.buf)
      local filename = vim.fn.fnamemodify(filepath, ":t")

      filename = filename == "" and "[No Name]" or filename

      local icon, icon_hl = get_icon(filepath)
      local modified = vim.bo[props.buf].modified
      local focused = props.focused
      local cursor = vim.api.nvim_win_get_cursor(props.win)
      local row = cursor[1]
      local col = cursor[2] + 1
      local total_lines = vim.fn.line("$")
      local mode = vim.fn.mode()
      local visual_info = nil
      local insert = false

      if mode:match("^i") and focused then
        insert = true
      elseif mode:match("[vV\22]") and focused then
        local wc = vim.fn.wordcount()
        visual_info = string.format(
          "%d lines, %d chars",
          math.abs(vim.fn.line("v") - vim.fn.line(".")) + 1,
          wc.visual_chars or 0
        )
      end

      return {
        icon and { " ", icon, group = icon_hl } or "",
        { " ", filename, gui = modified and "italic" or "" },
        modified and { "*", group = "InclineModified" } or "",
        { " [" .. row .. "/" .. total_lines .. ":" .. col .. "]", group = "LineNr" },
        visual_info and { " <<VISUAL ", visual_info, group = "InclineVisual" } or "",
        insert and { " <<INSERT", visual_info, group = "InclineInsert" } or "",
      }
    end

    require("incline").setup(opts)
  end,
}
