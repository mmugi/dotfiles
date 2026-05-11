local M = {}

function M.setup(palette)
  return {
    -- normal
    Normal = { fg = palette.fg, bg = palette.bg },
    NormalNC = { link = "Normal" },

    -- cursor
    Cursor = { fg = palette.black, bg = palette.purple },
    CursorIM = { link = "Cursor" },
    --lCursor = {},
    --TermCursor = {},

    -- line number
    LineNr = { fg = palette.lavender },
    CursorLineNr = { fg = palette.white },
    EndOfBuffer = { link = "LineNr" },

    -- cursor line
    CursorLine = { bg = palette.dark_purple },
    CursorColumn = { link = "CursorLine" },

    -- sign
    SignColumn = { fg = palette.neon_pink },
    CursorLineSign = { link = "SignColumn" },

    -- fold
    Folded = { fg = palette.lavender },
    FoldColumn = { link = "SignColumn" },
    CursorLineFold = { link = "SignColumn" },

    -- separator
    WinSeparator = { fg = palette.lavender },
    MsgSeparator = { link = "WinSeparator" },

    -- search
    Search = { fg = palette.white, bg = palette.muted_blue },
    CurSearch = { fg = palette.black, bg = palette.skyblue },
    IncSearch = { link = "CurSearch" },

    -- visual
    Visual = { fg = palette.white, bg = palette.purple },

    -- status line
    StatusLine = { link = "Normal" },
    StatusLineNC = { link = "StatusLine" },
    StatusLineTerm = { fg = palette.black, bg = palette.tarquoise },
    StatusLineTermNC = { link = "StatusLineTerm" },

    -- float
    NormalFloat = { link = "Normal" },
    FloatBorder = { link = "NormalFloat" },

    -- pmenu
    Pmenu = { link = "Normal" },
    PmenuSel = { fg = palette.white, bg = palette.blue_purple },
    PmenuMatch = { fg = palette.purple },
    PmenuMatchSel = { fg = palette.white, bg = palette.blue_purple },
    PmenuKind = { link = "Pmenu" },
    PmenuKindSel = { link = "PmenuSel" },
    PmenuExtra = { link = "Pmenu" },
    PmenuExtraSel = { link = "PmenuSel" },
    PmenuSbar = { link = "Pmenu" },
    PmenuThumb = { bg = palette.tarquoise },
    PmenuBorder = { link = "Pmenu" },

    -- syntax
    NonText = { fg = palette.lavender },
    Error = { fg = palette.scarlet },

    -- customs
    ErrTrailingWhitespace = { fg = palette.white, bg = palette.red },

    -- telescope
    TelescopeNormal = { link = "NormalFloat" },
    TelescopeMatching = { fg = palette.purple },
    TelescopePreviewMatch = { link = "CurSearch" },
    TelescopeSelection = { fg = palette.white, bg = palette.blue_purple },
    TelescopeBorder = { link = "FloatBorder" },
    TelescopePromptPrefix = { fg = palette.neon_green, bold = true },
    TelescopePromptCounter = { fg = palette.neon_pink, bold = true },
    TelescopeTitle = { fg = palette.pink, bold = true },
    --TelescopeResultsDiffDelete = { fg = palette.red },
    --TelescopeResultsDiffChange = { fg = palette.yellow },
    --TelescopeResultsDiffAdd = { fg = palette.pink },

    -- incline
    InclineNormal = { fg = palette.white },
    InclineNormalNC = { fg = palette.lavender },
    InclineInsert = { fg = palette.pink, italic = true },
    InclineVisual = { fg = palette.neon_green, italic = true },
    InclineModified = { fg = palette.neon_pink },
  }
end

return M
