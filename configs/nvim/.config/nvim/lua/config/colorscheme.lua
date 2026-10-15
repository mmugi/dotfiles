require("mmerr").setup({
  transparent_bg = true,
  overrides = function(palette)
    return {
      ErrTrailingWhitespace = { fg = palette.white, bg = palette.red },

      CursorInfoInsert = { fg = palette.pink, italic = true },
      CursorInfoVisual = { fg = palette.purple, italic = true },
      CursorInfoReplace = { fg = palette.turquoise, italic = true },

      ColumnGuide = { fg = palette.bg_blue },
    }
  end,
})
vim.cmd.colorscheme("mmerr")
