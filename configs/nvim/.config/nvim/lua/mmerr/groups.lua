local M = {}

function M.setup(palette)
  return {
    -- editor (help highlight-groups)
    Normal = { fg = palette.fg, bg = palette.bg },
    NormalNC = { link = "Normal" },

    Cursor = { fg = palette.black, bg = palette.purple },
    CursorIM = { link = "Cursor" },
    --lCursor = {},
    --TermCursor = {},
    CursorLine = { underline = true, sp = palette.purple },
    CursorColumn = { bg = palette.dark_purple },
    MatchParen = { fg = palette.white, bg = palette.blue_purple, bold = true },

    LineNr = { fg = palette.lavender },
    CursorLineNr = { fg = palette.white },
    EndOfBuffer = { link = "LineNr" },
    NonText = { fg = palette.lavender },

    SignColumn = { fg = palette.neon_pink },
    CursorLineSign = { link = "SignColumn" },

    Folded = { fg = palette.lavender },
    FoldColumn = { link = "SignColumn" },
    CursorLineFold = { link = "SignColumn" },

    WinSeparator = { fg = palette.lavender },
    MsgSeparator = { link = "WinSeparator" },

    Search = { fg = palette.white, bg = palette.muted_blue },
    CurSearch = { fg = palette.black, bg = palette.skyblue },
    IncSearch = { link = "CurSearch" },

    Visual = { fg = palette.white, bg = palette.purple },

    StatusLine = { link = "Normal" },
    StatusLineNC = { link = "StatusLine" },
    StatusLineTerm = { fg = palette.black, bg = palette.turquoise },
    StatusLineTermNC = { link = "StatusLineTerm" },

    NormalFloat = { link = "Normal" },
    FloatBorder = { link = "NormalFloat" },
    Title = { fg = palette.skyblue, bold = true },

    Pmenu = { link = "Normal" },
    PmenuSel = { fg = palette.white, bg = palette.blue_purple },
    PmenuMatch = { fg = palette.purple },
    PmenuMatchSel = { fg = palette.white, bg = palette.blue_purple },
    PmenuKind = { link = "Pmenu" },
    PmenuKindSel = { link = "PmenuSel" },
    PmenuExtra = { link = "Pmenu" },
    PmenuExtraSel = { link = "PmenuSel" },
    PmenuSbar = { link = "Pmenu" },
    PmenuThumb = { bg = palette.turquoise },
    PmenuBorder = { link = "Pmenu" },

    DiffAdd = { bg = palette.dark_green },
    DiffChange = { bg = palette.dim_purple },
    DiffText = { fg = palette.black, bg = palette.purple },
    DiffDelete = { fg = palette.red, bg = palette.dark_red },

    -- diagnostic (help diagnostic-highlights)
    DiagnosticError = { fg = palette.red },
    DiagnosticWarn = { fg = palette.yellow },
    DiagnosticInfo = { fg = palette.blue },
    DiagnosticHint = { fg = palette.periwinkle },
    DiagnosticOk = { fg = palette.turquoise },
    DiagnosticUnderlineError = { undercurl = true, sp = palette.red },
    DiagnosticUnderlineWarn = { undercurl = true, sp = palette.yellow },
    DiagnosticUnderlineInfo = { undercurl = true, sp = palette.blue },
    DiagnosticUnderlineHint = { undercurl = true, sp = palette.periwinkle },
    DiagnosticUnderlineOk = { undercurl = true, sp = palette.turquoise },
    DiagnosticDeprecated = { strikethrough = true, sp = palette.red },

    -- syntax (help group-name)
    Comment = { fg = palette.gray },

    Constant = { fg = palette.turquoise },
    String = { fg = palette.purple },
    Character = { link = "String" },

    Identifier = { fg = palette.fg },
    Function = { fg = palette.fg },

    Statement = { fg = palette.fg },
    Operator = { fg = palette.fg },

    PreProc = { fg = palette.pink },

    Type = { fg = palette.fg },

    Special = { fg = palette.blue },
    Delimiter = { fg = palette.fg },
    SpecialComment = { fg = palette.gray, italic = true, bold = true },
    Debug = { fg = palette.lavender },

    Underlined = { underline = true },
    Error = { fg = palette.scarlet },
    Todo = { fg = palette.black, bg = palette.yellow, bold = true },

    Added = { fg = palette.turquoise },
    Changed = { fg = palette.pink },
    Removed = { fg = palette.red },

    -- syntax (sh)
    shCommandSub = { fg = palette.fg },
    shArithmetic = { fg = palette.fg },

    -- syntax (python)
    pythonDecoratorName = { link = "Define" },

    -- tree-sitter
    ["@variable"] = { fg = palette.fg },
    ["@constructor.lua"] = { link = "Delimiter" },

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
    InclineConflict = { fg = palette.red, bold = true },

    -- cursorinfo
    CursorInfoInsert = { fg = palette.pink, italic = true },
    CursorInfoVisual = { fg = palette.purple, italic = true },
    CursorInfoReplace = { fg = palette.turquoise, italic = true },
  }
end

return M
