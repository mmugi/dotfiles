return {
  "mmugi/mmerr.nvim",
  lazy = false,
  priority = 1000,
  init = function()
    vim.g.mmerr_autoreload = true
  end,
  opts = {
    transparent_bg = true,
    edit_highlights = function(groups, palette)
      groups.ErrTrailingWhitespace = { fg = palette.white, bg = palette.red }

      groups.CursorInfoInsert = { fg = palette.folly, italic = true }
      groups.CursorInfoVisual = { fg = palette.green, italic = true }
      groups.CursorInfoReplace = { link = "CursorInfoInsert" }

      groups.ColumnGuide = { fg = palette.koamaru }

      groups.InclineModified = { fg = palette.pink }
      groups.InclineConflict = { fg = palette.red, bold = true }
    end,
  },
}
