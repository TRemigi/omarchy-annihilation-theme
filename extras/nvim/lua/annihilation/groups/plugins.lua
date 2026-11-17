-- Only what a plugin's own defaults get wrong: most link to the core groups above with
-- `default = true` and already land on the right colours.
return function(c)
  local hl = {
    -- blink.cmp
    BlinkCmpMenu = "Pmenu",
    BlinkCmpMenuBorder = "FloatBorder",
    BlinkCmpMenuSelection = "PmenuSel",
    BlinkCmpLabel = { fg = c.fg },
    BlinkCmpLabelMatch = { fg = c.teal, bold = true },
    BlinkCmpLabelDeprecated = { fg = c.comment, strikethrough = true },
    BlinkCmpLabelDetail = { fg = c.comment },
    BlinkCmpLabelDescription = { fg = c.comment },
    BlinkCmpGhostText = { fg = c.faint },
    BlinkCmpDoc = "NormalFloat",
    BlinkCmpDocBorder = "FloatBorder",
    BlinkCmpSignatureHelp = "NormalFloat",
    BlinkCmpSignatureHelpBorder = "FloatBorder",
    BlinkCmpSignatureHelpActiveParameter = "LspSignatureActiveParameter",

    -- snacks.nvim (the picker, explorer and notifier link to the core groups)
    SnacksIndent = { fg = c.lighter_bg, nocombine = true },
    SnacksIndentScope = { fg = c.teal, nocombine = true },
    SnacksPickerMatch = { fg = c.teal, bold = true },
    SnacksPickerDir = { fg = c.comment },
    SnacksBackdrop = { bg = c.darkest_bg },
    SnacksDashboardHeader = { fg = c.teal },
    SnacksDashboardKey = { fg = c.amber },
    SnacksDashboardDesc = { fg = c.dark_fg },
    SnacksDashboardIcon = { fg = c.bright_teal },
    SnacksDashboardFooter = { fg = c.comment, italic = true },

    -- gitsigns
    GitSignsAdd = { fg = c.bright_moss },
    GitSignsChange = { fg = c.amber },
    GitSignsDelete = { fg = c.rose },
    GitSignsStagedAdd = { fg = c.moss },
    GitSignsStagedChange = { fg = c.mix(c.amber, c.bg, 0.45) },
    GitSignsStagedDelete = { fg = c.mix(c.rose, c.bg, 0.45) },
    GitSignsCurrentLineBlame = { fg = c.comment, italic = true },

    -- flash.nvim: the labels are the one place a jump may shout
    FlashBackdrop = { fg = c.comment },
    FlashMatch = { fg = c.light_fg, bg = c.tint(c.teal, 0.3) },
    FlashCurrent = { fg = c.selection_fg, bg = c.amber },
    FlashLabel = { fg = c.selection_fg, bg = c.rose, bold = true },

    -- mini.nvim
    MiniIndentscopeSymbol = { fg = c.teal, nocombine = true },
    MiniCursorword = { bg = c.tint(c.teal, 0.18) },
    MiniCursorwordCurrent = "MiniCursorword",
    MiniIconsAzure = { fg = c.teal },
    MiniIconsBlue = { fg = c.rose },
    MiniIconsCyan = { fg = c.bright_teal },
    MiniIconsGreen = { fg = c.bright_moss },
    MiniIconsGrey = { fg = c.dark_fg },
    MiniIconsOrange = { fg = c.amber },
    MiniIconsPurple = { fg = c.bright_mauve },
    MiniIconsRed = { fg = c.error },
    MiniIconsYellow = { fg = c.light_fg },
    MiniHipatternsFixme = { fg = c.selection_fg, bg = c.error, bold = true },
    MiniHipatternsHack = { fg = c.selection_fg, bg = c.amber, bold = true },
    MiniHipatternsNote = { fg = c.selection_fg, bg = c.teal, bold = true },
    MiniHipatternsTodo = { fg = c.selection_fg, bg = c.bright_moss, bold = true },

    -- neo-tree
    NeoTreeNormal = { fg = c.fg, bg = c.darker_bg },
    NeoTreeNormalNC = "NeoTreeNormal",
    NeoTreeEndOfBuffer = { fg = c.darker_bg, bg = c.darker_bg },
    NeoTreeWinSeparator = { fg = c.lighter_bg, bg = c.darker_bg },
    NeoTreeFloatBorder = "FloatBorder",
    NeoTreeCursorLine = { bg = c.selection },
    NeoTreeRootName = { fg = c.teal, bold = true },
    NeoTreeDirectoryName = { fg = c.dark_fg },
    NeoTreeDirectoryIcon = { fg = c.teal },
    NeoTreeIndentMarker = { fg = c.lighter_bg },
    NeoTreeDotfile = { fg = c.comment },
    NeoTreeGitAdded = { fg = c.bright_moss },
    NeoTreeGitModified = { fg = c.amber },
    NeoTreeGitDeleted = { fg = c.rose },
    NeoTreeGitUntracked = { fg = c.bright_mauve },
    NeoTreeGitConflict = { fg = c.error, bold = true },
    NeoTreeGitIgnored = { fg = c.comment },

    -- nvim-treesitter-context
    TreesitterContext = { bg = c.dark_bg },
    TreesitterContextLineNumber = { fg = c.teal, bg = c.dark_bg },
    TreesitterContextBottom = { underline = true, sp = c.lighter_bg },
    TreesitterContextSeparator = { fg = c.lighter_bg },

    -- vim-illuminate
    IlluminatedWordText = { bg = c.tint(c.teal, 0.18) },
    IlluminatedWordRead = "IlluminatedWordText",
    IlluminatedWordWrite = { bg = c.tint(c.teal, 0.18), underline = true },

    -- render-markdown.nvim: its defaults borrow the diff groups
    RenderMarkdownH1Bg = { bg = c.tint(c.amber, 0.16) },
    RenderMarkdownH2Bg = { bg = c.tint(c.rose, 0.16) },
    RenderMarkdownH3Bg = { bg = c.tint(c.bright_mauve, 0.16) },
    RenderMarkdownH4Bg = { bg = c.tint(c.teal, 0.16) },
    RenderMarkdownH5Bg = { bg = c.tint(c.bright_moss, 0.16) },
    RenderMarkdownH6Bg = { bg = c.tint(c.dark_fg, 0.12) },
    RenderMarkdownCode = { bg = c.dark_bg },
    RenderMarkdownCodeInline = { fg = c.bright_moss, bg = c.dark_bg },
    RenderMarkdownBullet = { fg = c.amber },
    RenderMarkdownQuote = { fg = c.comment },
    RenderMarkdownTableHead = { fg = c.teal, bold = true },
    RenderMarkdownTableRow = { fg = c.dark_fg },
    RenderMarkdownLink = { fg = c.teal },

    -- nvim-dap and its UI
    DapBreakpoint = { fg = c.rose },
    DapBreakpointCondition = { fg = c.amber },
    DapBreakpointRejected = { fg = c.comment },
    DapLogPoint = { fg = c.teal },
    DapStopped = { fg = c.amber },
    DapStoppedLine = { bg = c.tint(c.amber, 0.14) },
    DapUIScope = { fg = c.teal },
    DapUIType = "Type",
    DapUIValue = "Normal",
    DapUIModifiedValue = { fg = c.amber, bold = true },
    DapUIDecoration = { fg = c.teal },
    DapUIThread = { fg = c.bright_moss },
    DapUIStoppedThread = { fg = c.teal },
    DapUISource = { fg = c.bright_mauve },
    DapUILineNumber = { fg = c.teal },
    DapUIFloatBorder = "FloatBorder",
    DapUIWatchesEmpty = { fg = c.rose },
    DapUIWatchesValue = { fg = c.bright_moss },
    DapUIWatchesError = { fg = c.error },
    DapUIBreakpointsPath = { fg = c.teal },
    DapUIBreakpointsInfo = { fg = c.bright_moss },
    DapUIBreakpointsCurrentLine = { fg = c.bright_moss, bold = true },
    DapUIBreakpointsLine = { fg = c.teal },

    -- mason.nvim
    MasonHeader = { fg = c.selection_fg, bg = c.teal, bold = true },
    MasonHeaderSecondary = { fg = c.selection_fg, bg = c.amber, bold = true },
    MasonHighlight = { fg = c.teal },
    MasonHighlightBlock = { fg = c.selection_fg, bg = c.teal },
    MasonHighlightBlockBold = { fg = c.selection_fg, bg = c.teal, bold = true },
    MasonHighlightSecondary = { fg = c.amber },
    MasonHighlightBlockSecondary = { fg = c.selection_fg, bg = c.amber },
    MasonHighlightBlockBoldSecondary = { fg = c.selection_fg, bg = c.amber, bold = true },
    MasonMuted = { fg = c.comment },
    MasonMutedBlock = { fg = c.comment, bg = c.lighter_bg },
    MasonError = { fg = c.error },

    -- lazy.nvim
    LazyButton = { fg = c.dark_fg, bg = c.lighter_bg },
    LazyButtonActive = { fg = c.selection_fg, bg = c.teal, bold = true },
    LazyH1 = { fg = c.selection_fg, bg = c.teal, bold = true },
    LazyH2 = { fg = c.teal, bold = true },
    LazyProp = { fg = c.comment },
    LazyReasonPlugin = { fg = c.rose },
    LazyReasonEvent = { fg = c.amber },
    LazyReasonCmd = { fg = c.amber },
    LazyReasonFt = { fg = c.bright_mauve },
    LazyReasonStart = { fg = c.bright_moss },
    LazyReasonSource = { fg = c.teal },
    LazyReasonImport = { fg = c.teal },
    LazyReasonRuntime = { fg = c.teal },
    LazyReasonKeys = { fg = c.amber },
    LazyReasonRequire = { fg = c.bright_teal },
    LazySpecial = { fg = c.teal },
    LazyCommit = { fg = c.bright_moss },
    LazyCommitType = { fg = c.bright_mauve },
    LazyCommitScope = { fg = c.dark_fg, italic = true },
    LazyDimmed = { fg = c.comment },
    LazyUrl = { fg = c.teal },
    LazyDir = { fg = c.dark_fg },
  }

  -- blink.cmp's kind colours, by what the item is: the same hues the syntax uses
  local kinds = {
    Text = c.fg, Method = c.rose, Function = c.rose, Constructor = c.teal, Field = c.dark_fg,
    Variable = c.fg, Class = c.teal, Interface = c.teal, Module = c.dark_fg, Property = c.dark_fg,
    Unit = c.amber, Value = c.amber, Enum = c.teal, Keyword = c.bright_mauve, Snippet = c.bright_moss,
    Color = c.bright_teal, File = c.dark_fg, Reference = c.bright_rose, Folder = c.dark_fg,
    EnumMember = c.amber, Constant = c.amber, Struct = c.teal, Event = c.bright_mauve,
    Operator = c.punct, TypeParameter = c.teal, Copilot = c.bright_teal,
  }
  hl.BlinkCmpKind = { fg = c.dark_fg }
  for kind, color in pairs(kinds) do
    hl["BlinkCmpKind" .. kind] = { fg = color }
  end
  return hl
end
