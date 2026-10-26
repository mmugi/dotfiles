return {
  "mmugi/mmerr.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    transparent_bg = true,
    highlight_overrides = function(palette)
      return {
        ErrTrailingWhitespace = { fg = palette.white, bg = palette.red },

        CursorInfoInsert = { fg = palette.pink, italic = true },
        CursorInfoVisual = { fg = palette.lime, italic = true },
        CursorInfoReplace = { fg = palette.turquoise, italic = true },

        ColumnGuide = { fg = palette.bg_blue },

        InclineModified = { fg = palette.pink },
        InclineConflict = { fg = palette.red, bold = true },
      }
    end,
  },
}
