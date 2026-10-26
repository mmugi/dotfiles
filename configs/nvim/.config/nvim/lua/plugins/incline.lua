local icon_enabled = true

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
    vim.opt.fillchars:append({ stl = "─", stlnc = "─" })

    -- ステータスラインを上下分割の区切り線として使う。
    -- ステータスラインのハイライトグループ群を WinSeparator にリンクする。
    local function link_statusline()
      for _, group in ipairs({ "StatusLine", "StatusLineNC", "StatusLineTerm", "StatusLineTermNC" }) do
        vim.api.nvim_set_hl(0, group, { link = "WinSeparator" })
      end
    end
    link_statusline()
    -- カラースキームを読み直すとリンクがリセットされるのでautocmdでリンクし直す
    vim.api.nvim_create_autocmd("ColorScheme", { callback = link_statusline })

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

    vim.api.nvim_create_autocmd("FileChangedShell", {
      callback = function(args)
        if vim.v.fcs_reason == "conflict" then
          vim.b[args.buf].incline_conflict = true
        end
        -- keep nvim's own warning and prompt
        vim.v.fcs_choice = "ask"
      end,
    })

    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
      callback = function(args)
        vim.b[args.buf].incline_conflict = nil
      end,
    })

    opts.render = function(props)
      local filepath = vim.api.nvim_buf_get_name(props.buf)
      local filename = vim.fn.fnamemodify(filepath, ":t")

      filename = filename == "" and "[No Name]" or filename

      local icon, icon_hl = get_icon(filepath)
      local modified = vim.bo[props.buf].modified
      local conflict = vim.b[props.buf].incline_conflict

      return {
        icon and { " ", icon, group = icon_hl } or "",
        { " ", filename, gui = modified and "italic" or "" },
        modified and { "*", group = "InclineModified" } or "",
        conflict and { " CONFLICT!", group = "InclineConflict" } or "",
      }
    end

    require("incline").setup(opts)
  end,
}
