local M = {}

function M.setup(palette)
  return {
    -- customs
    ErrTrailingWhitespace = { fg = palette.white, bg = palette.red },

    -- editor (help highlight-groups)
    Normal = { fg = palette.fg, bg = palette.bg },
    NormalNC = { link = "Normal" },

    Cursor = { fg = palette.black, bg = palette.purple },
    CursorIM = { link = "Cursor" },
    lCursor = { link = "Cursor" },
    TermCursor = { reverse = true },

    CursorLine = { underline = true, sp = palette.purple },
    CursorColumn = { bg = palette.bg_lavender },
    ColorColumn = { bg = palette.bg_lavender },
    MatchParen = { fg = palette.white, bg = palette.iris, bold = true },

    LineNr = { fg = palette.lavender },
    LineNrAbove = { link = "LineNr" },
    LineNrBelow = { link = "LineNr" },
    CursorLineNr = { fg = palette.white },

    EndOfBuffer = { link = "LineNr" },
    NonText = { fg = palette.lavender },
    Whitespace = { link = "NonText" },
    SpecialKey = { link = "Special" },
    Conceal = { fg = palette.gray },

    SignColumn = { fg = palette.rose },
    CursorLineSign = { link = "SignColumn" },

    Folded = { fg = palette.lavender },
    FoldColumn = { link = "SignColumn" },
    CursorLineFold = { link = "SignColumn" },

    Directory = { fg = palette.blue },
    QuickFixLine = { fg = palette.white, bg = palette.iris },

    WinSeparator = { fg = palette.lavender },
    MsgSeparator = { link = "WinSeparator" },

    Search = { fg = palette.white, bg = palette.bg_slate },
    CurSearch = { fg = palette.black, bg = palette.sky },
    IncSearch = { link = "CurSearch" },
    Substitute = { link = "Search" },

    Visual = { fg = palette.white, bg = palette.purple },
    VisualNOS = { link = "Visual" },

    StatusLine = { link = "Normal" },
    StatusLineNC = { link = "StatusLine" },
    StatusLineTerm = { fg = palette.black, bg = palette.turquoise },
    StatusLineTermNC = { link = "StatusLineTerm" },
    WinBar = { link = "Normal" },
    WinBarNC = { link = "NormalNC" },
    TabLine = { fg = palette.lavender },
    TabLineSel = { fg = palette.white, bold = true },
    TabLineFill = { link = "TabLine" },
    WildMenu = { link = "PmenuSel" },

    MsgArea = {},
    ErrorMsg = { fg = palette.red },
    WarningMsg = { fg = palette.yellow },
    OkMsg = { fg = palette.turquoise },
    MoreMsg = { fg = palette.mint, bold = true },
    ModeMsg = { fg = palette.fg, bold = true },
    Question = { fg = palette.lime },
    StderrMsg = { link = "ErrorMsg" },
    StdoutMsg = {},

    NormalFloat = { link = "Normal" },
    FloatBorder = { link = "NormalFloat" },
    Title = { fg = palette.sky, bold = true },
    FloatTitle = { link = "Title" },
    FloatFooter = { link = "FloatTitle" },
    FloatShadow = { bg = palette.black, blend = 80 },
    FloatShadowThrough = { bg = palette.black, blend = 100 },

    Pmenu = { link = "Normal" },
    PmenuSel = { fg = palette.white, bg = palette.iris },
    PmenuMatch = { fg = palette.purple },
    PmenuMatchSel = { fg = palette.white, bg = palette.iris },
    PmenuKind = { link = "Pmenu" },
    PmenuKindSel = { link = "PmenuSel" },
    PmenuExtra = { link = "Pmenu" },
    PmenuExtraSel = { link = "PmenuSel" },
    PmenuSbar = { link = "Pmenu" },
    PmenuThumb = { bg = palette.turquoise },
    PmenuBorder = { link = "Pmenu" },
    PmenuShadow = { link = "FloatShadow" },
    PmenuShadowThrough = { link = "FloatShadowThrough" },

    ComplMatchIns = {},
    ComplHint = { link = "NonText" },
    ComplHintMore = { link = "MoreMsg" },
    PreInsert = { link = "Added" },
    SnippetTabstop = { link = "Visual" },
    SnippetTabstopActive = { link = "SnippetTabstop" },

    DiffAdd = { bg = palette.bg_green },
    DiffChange = { bg = palette.bg_blue },
    DiffText = { fg = palette.white, bg = palette.pink },
    DiffTextAdd = { link = "DiffText" },
    DiffDelete = { fg = palette.red, bg = palette.bg_red },

    SpellBad = { undercurl = true, sp = palette.red },
    SpellCap = { undercurl = true, sp = palette.yellow },
    SpellLocal = { undercurl = true, sp = palette.turquoise },
    SpellRare = { undercurl = true, sp = palette.sky },

    -- diagnostic (help diagnostic-highlights)
    DiagnosticError = { fg = palette.red },
    DiagnosticWarn = { fg = palette.yellow },
    DiagnosticInfo = { fg = palette.blue },
    DiagnosticHint = { fg = palette.periwinkle },
    DiagnosticOk = { fg = palette.turquoise },

    DiagnosticVirtualTextError = { link = "DiagnosticError" },
    DiagnosticVirtualTextWarn = { link = "DiagnosticWarn" },
    DiagnosticVirtualTextInfo = { link = "DiagnosticInfo" },
    DiagnosticVirtualTextHint = { link = "DiagnosticHint" },
    DiagnosticVirtualTextOk = { link = "DiagnosticOk" },

    DiagnosticVirtualLinesError = { link = "DiagnosticError" },
    DiagnosticVirtualLinesWarn = { link = "DiagnosticWarn" },
    DiagnosticVirtualLinesInfo = { link = "DiagnosticInfo" },
    DiagnosticVirtualLinesHint = { link = "DiagnosticHint" },
    DiagnosticVirtualLinesOk = { link = "DiagnosticOk" },

    DiagnosticUnderlineError = { undercurl = true, sp = palette.red },
    DiagnosticUnderlineWarn = { undercurl = true, sp = palette.yellow },
    DiagnosticUnderlineInfo = { undercurl = true, sp = palette.blue },
    DiagnosticUnderlineHint = { undercurl = true, sp = palette.periwinkle },
    DiagnosticUnderlineOk = { undercurl = true, sp = palette.turquoise },

    DiagnosticFloatingError = { link = "DiagnosticError" },
    DiagnosticFloatingWarn = { link = "DiagnosticWarn" },
    DiagnosticFloatingInfo = { link = "DiagnosticInfo" },
    DiagnosticFloatingHint = { link = "DiagnosticHint" },
    DiagnosticFloatingOk = { link = "DiagnosticOk" },

    DiagnosticSignError = { link = "DiagnosticError" },
    DiagnosticSignWarn = { link = "DiagnosticWarn" },
    DiagnosticSignInfo = { link = "DiagnosticInfo" },
    DiagnosticSignHint = { link = "DiagnosticHint" },
    DiagnosticSignOk = { link = "DiagnosticOk" },

    DiagnosticDeprecated = { strikethrough = true, sp = palette.red },
    DiagnosticUnnecessary = { link = "Comment" },

    -- lsp (help lsp-highlight)
    LspReferenceText = { bg = palette.bg_blue },
    LspReferenceRead = { link = "LspReferenceText" },
    LspReferenceWrite = { link = "LspReferenceText" },
    LspReferenceTarget = { link = "LspReferenceText" },

    LspInlayHint = { link = "NonText" },
    LspCodeLens = { link = "NonText" },
    LspCodeLensSeparator = { link = "LspCodeLens" },

    LspSignatureActiveParameter = { link = "Visual" },

    -- syntax (help group-name)
    Comment = { fg = palette.gray },

    Constant = { fg = palette.turquoise },
    String = { fg = palette.purple },
    Character = { link = "String" },
    Number = { link = "Constant" },
    Boolean = { link = "Constant" },
    Float = { link = "Number" },

    Identifier = { fg = palette.fg },
    Function = { fg = palette.fg },

    Statement = { fg = palette.fg },
    Conditional = { link = "Statement" },
    Repeat = { link = "Statement" },
    Label = { link = "Statement" },
    Operator = { fg = palette.fg },
    Keyword = { link = "Statement" },
    Exception = { link = "Statement" },

    PreProc = { fg = palette.pink },
    Include = { link = "PreProc" },
    Define = { link = "PreProc" },
    Macro = { link = "PreProc" },
    PreCondit = { link = "PreProc" },

    Type = { fg = palette.fg },
    StorageClass = { link = "Type" },
    Structure = { link = "Type" },
    Typedef = { link = "Type" },

    Special = { fg = palette.blue },
    SpecialChar = { link = "Special" },
    Tag = { link = "Special" },
    Delimiter = { fg = palette.fg },
    SpecialComment = { fg = palette.gray, italic = true, bold = true },
    Debug = { fg = palette.lavender },

    Underlined = { underline = true },
    Ignore = { link = "Normal" },
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

    -- tree-sitter (help treesitter-highlight-groups)
    ["@variable"] = { fg = palette.fg },
    ["@variable.builtin"] = { link = "Special" },
    ["@variable.parameter.builtin"] = { link = "Special" },

    ["@constant"] = { link = "Constant" },
    ["@constant.builtin"] = { link = "Special" },

    ["@module"] = { link = "Structure" },
    ["@module.builtin"] = { link = "Special" },

    ["@label"] = { link = "Label" },

    ["@string"] = { link = "String" },
    ["@string.regexp"] = { link = "@string.special" },
    ["@string.escape"] = { link = "@string.special" },
    ["@string.special"] = { link = "SpecialChar" },
    ["@string.special.url"] = { link = "Underlined" },

    ["@character"] = { link = "Character" },
    ["@character.special"] = { link = "SpecialChar" },

    ["@boolean"] = { link = "Boolean" },

    ["@number"] = { link = "Number" },
    ["@number.float"] = { link = "Float" },

    ["@type"] = { link = "Type" },
    ["@type.builtin"] = { link = "Special" },

    ["@attribute"] = { link = "Macro" },
    ["@attribute.builtin"] = { link = "Special" },

    ["@property"] = { link = "Identifier" },

    ["@function"] = { link = "Function" },
    ["@function.builtin"] = { link = "Special" },

    ["@constructor"] = { link = "Special" },

    ["@operator"] = { link = "Operator" },

    ["@keyword"] = { link = "Keyword" },

    ["@punctuation.special"] = { link = "Special" },

    ["@comment"] = { link = "Comment" },
    ["@comment.error"] = { link = "DiagnosticError" },
    ["@comment.warning"] = { link = "DiagnosticWarn" },
    ["@comment.todo"] = { link = "Todo" },
    ["@comment.note"] = { link = "DiagnosticInfo" },

    ["@markup.strong"] = { bold = true },
    ["@markup.italic"] = { italic = true },
    ["@markup.strikethrough"] = { strikethrough = true },
    ["@markup.underline"] = { underline = true },
    ["@markup.heading"] = { link = "Title" },
    ["@markup.link"] = { link = "Underlined" },

    ["@diff.plus"] = { link = "Added" },
    ["@diff.minus"] = { link = "Removed" },
    ["@diff.delta"] = { link = "Changed" },

    ["@tag"] = { link = "Tag" },
    ["@tag.builtin"] = { link = "Special" },

    ["@constructor.lua"] = { link = "Delimiter" },

    -- telescope
    TelescopeNormal = { link = "NormalFloat" },
    TelescopeMatching = { fg = palette.purple },
    TelescopePreviewMatch = { link = "CurSearch" },
    TelescopeSelection = { fg = palette.white, bg = palette.iris },
    TelescopeBorder = { link = "FloatBorder" },
    TelescopePromptPrefix = { fg = palette.purple, bold = true },
    TelescopePromptCounter = { fg = palette.turquoise },
    TelescopeTitle = { bold = true },
    --TelescopeResultsDiffDelete = { fg = palette.red },
    --TelescopeResultsDiffChange = { fg = palette.yellow },
    --TelescopeResultsDiffAdd = { fg = palette.pink },

    -- incline
    InclineNormal = { fg = palette.white },
    InclineNormalNC = { fg = palette.lavender },
    InclineModified = { fg = palette.rose },
    InclineConflict = { fg = palette.red, bold = true },

    -- cursorinfo
    CursorInfoInsert = { fg = palette.pink, italic = true },
    CursorInfoVisual = { fg = palette.purple, italic = true },
    CursorInfoReplace = { fg = palette.turquoise, italic = true },

    -- columnguide
    ColumnGuide = { fg = palette.bg_blue },
  }
end

return M
