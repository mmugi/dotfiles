local icon_enabled = true

return {
  "b0o/incline.nvim",
  event = "VeryLazy",
  dependencies = {
    { "nvim-mini/mini.icons", opts = {} },
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

    local diagnostic_labels = {
      { severity = vim.diagnostic.severity.ERROR, text = "E", group = "DiagnosticError" },
      { severity = vim.diagnostic.severity.WARN, text = "W", group = "DiagnosticWarn" },
      { severity = vim.diagnostic.severity.INFO, text = "I", group = "DiagnosticInfo" },
      { severity = vim.diagnostic.severity.HINT, text = "H", group = "DiagnosticHint" },
    }
    local function get_diagnostics(buf)
      local counts = vim.diagnostic.count(buf)
      local diagnostics = {}
      for _, label in ipairs(diagnostic_labels) do
        if counts[label.severity] then
          table.insert(diagnostics, { " ", label.text .. counts[label.severity], group = label.group })
        end
      end
      return diagnostics
    end
    -- incline は DiagnosticChanged では描き直さないので、件数が変わったら描き直す。
    vim.api.nvim_create_autocmd("DiagnosticChanged", {
      callback = function()
        require("incline").refresh()
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
        get_diagnostics(props.buf),
        conflict and { " CONFLICT!", group = "InclineConflict" } or "",
      }
    end

    require("incline").setup(opts)
  end,
}
