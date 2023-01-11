local view, colors, styles = view, view.colors, view.styles

local bg = 0x1e1e1e
local bg0 = 0x282828
local bg0_h = 0x21201d
local bg1 = 0x36393c
local bg2 = 0x454950
local bg3 = 0x545c66
local bg4 = 0x646f7c
local bg0_s = 0x2f3032
local gray7 = 0x8499a8
local gray8 = 0x748392
local fg0 = 0xc7f1fb
local fg1 = 0xb2dbeb
local fg2 = 0xa1c4d5
local fg3 = 0x93aebd
local fg4 = 0x8499a8

-- muted

local red = 0x1d24cc
local green = 0x1a9798
local yellow = 0x2199d7
local blue = 0x888545
local purple = 0x8662b1
local aqua = 0x6a9d68
local orange = 0x0e5dd6

-- bright

-- local red = 0x3449fb
-- local green = 0x26bbb8
-- local yellow = 0x2fbdfa
-- local blue = 0x98a583
-- local purple = 0x9b86d3
-- local aqua = 0x7cc08e
-- local orange = 0x1980fe

-- Greyscale colors.
colors.black = 0x000000
colors.light_black = 0x333333
colors.dark_grey = 0x666666
colors.grey = 0x999999 -- unused
colors.light_grey = 0xCCCCCC
colors.white = 0xFFFFFF -- unused

-- Normal colors.
colors.red = red
colors.orange = orange
colors.yellow = yellow
colors.lime = 0x00CC99
colors.green = green
colors.teal = 0x808000
colors.blue = blue
colors.violet = violet
colors.purple = purple
colors.magenta = magenta

-- Predefined styles.
styles[view.STYLE_DEFAULT] = {
  font = font, size = size, fore = 0x6a6a6a, back = bg0
}
styles[view.STYLE_LINENUMBER] = {fore = bg2, back = bg0}
styles[view.STYLE_BRACELIGHT] = {fore = red}
styles[view.STYLE_BRACEBAD] = {fore = colors.red}
styles[view.STYLE_INDENTGUIDE] = {fore = 0x757575}
styles[view.STYLE_CALLTIP] = {fore = colors.light_grey, back = colors.light_black}

-- Tag styles.
styles[lexer.ANNOTATION] = {fore = purple}
styles[lexer.ATTRIBUTE] = {fore = bg4}
styles[lexer.BOLD] = {bold = true}
styles[lexer.CLASS] = {fore = green}
styles[lexer.CODE] = {fore = gray7, eolfilled = true}
styles[lexer.COMMENT] = {fore = bg3}
styles[lexer.CONSTANT] = {fore = red, underline = true}
styles[lexer.EMBEDDED] = {fore = bg4}
styles[lexer.ERROR] = {fore = red}
styles[lexer.FUNCTION] = {fore = blue}
-- styles[lexer.FUNCTION_BUILTIN] = {fore = blue}
styles[lexer.HEADING] = {fore = purple}
styles[lexer.ITALIC] = {italic = true}
styles[lexer.KEYWORD] = {fore = green}
styles[lexer.LABEL] = {fore = fg3}
styles[lexer.LINK] = {underline = true}
styles[lexer.LIST] = {fore = colors.teal}
styles[lexer.NUMBER] = {fore = aqua}
styles[lexer.OPERATOR] = {fore = bg4}
styles[lexer.PREPROCESSOR] = {fore = blue, underline = true}
styles[lexer.REFERENCE] = {underline = true}
styles[lexer.REGEX] = {fore = orange}
styles[lexer.STRING] = {fore = yellow}
styles[lexer.TAG] = {fore = blue}
styles[lexer.TYPE] = {fore = orange}
styles[lexer.UNDERLINE] = {underline = true}
styles[lexer.VARIABLE_BUILTIN] = {fore = red}
styles[lexer.KEYWORD .. '.ctl'] = {fore = purple}

-- CSS.
styles.property = styles[lexer.ATTRIBUTE]
-- styles.pseudoclass = {}
-- styles.pseudoelement = {}
-- Diff.
styles.addition = {fore = colors.green}
styles.deletion = {fore = colors.red}
styles.change = {fore = colors.yellow}
-- HTML.
styles.tag_unknown = styles.tag .. {italics = true}
styles.attribute_unknown = styles.attribute .. {italics = true}
-- Latex, TeX, and Texinfo.
styles.command = styles[lexer.KEYWORD]
styles.command_section = styles[lexer.HEADING]
styles.environment = styles[lexer.TYPE]
styles.environment_math = styles[lexer.NUMBER]
-- Makefile.
-- styles.target = {}
-- Markdown.
-- styles.hr = {}
-- XML.
-- styles.cdata = {}
-- YAML.
styles.error_indent = {back = colors.red}

-- Caret and Selection Styles.
view.element_color[view.ELEMENT_CARET] = fg4
view.element_color[view.ELEMENT_CARET_ADDITIONAL] = bg4
view.element_color[view.ELEMENT_SELECTION_BACK] = gray8
view.element_color[view.ELEMENT_SELECTION_TEXT] = bg1
view.element_color[view.ELEMENT_SELECTION_INACTIVE_BACK] = bg1
view.element_color[view.ELEMENT_SELECTION_INACTIVE_TEXT] = gray8
view.element_color[view.ELEMENT_SELECTION_ADDITIONAL_BACK] = gray8
view.element_color[view.ELEMENT_SELECTION_ADDITIONAL_TEXT] = bg1
view.element_color[view.ELEMENT_SELECTION_SECONDARY_BACK] = gray8
view.element_color[view.ELEMENT_SELECTION_SECONDARY_TEXT] = bg1
view.element_color[view.ELEMENT_WHITE_SPACE] = bg2
view.element_color[view.ELEMENT_CARET_LINE_BACK] = bg3

-- Markers.
-- view.marker_fore[textadept.bookmarks.MARK_BOOKMARK] = colors.black
view.marker_back[textadept.bookmarks.MARK_BOOKMARK] = colors.blue
-- view.marker_fore[textadept.run.MARK_WARNING] = colors.black
view.marker_back[textadept.run.MARK_WARNING] = colors.yellow
-- view.marker_fore[textadept.run.MARK_ERROR] = colors.black
view.marker_back[textadept.run.MARK_ERROR] = colors.red
for i = buffer.MARKNUM_FOLDEREND, buffer.MARKNUM_FOLDEROPEN do -- fold margin
  view.marker_fore[i] = colors.black
  view.marker_back[i] = colors.dark_grey
  view.marker_back_selected[i] = colors.light_grey
end

-- Indicators.
view.indic_fore[ui.find.INDIC_FIND] = colors.dark_grey
view.indic_alpha[ui.find.INDIC_FIND] = 32
view.indic_outline_alpha[ui.find.INDIC_FIND] = 128

view.indic_fore[textadept.editing.INDIC_HIGHLIGHT] = colors.dark_grey
view.indic_alpha[textadept.editing.INDIC_HIGHLIGHT] = 32
view.indic_outline_alpha[textadept.editing.INDIC_HIGHLIGHT] = 128


-- Call tips.
view.call_tip_fore_hlt = colors.blue

-- Long Lines.
view.edge_color = colors.light_black

-- Find & replace pane entries.
ui.find.entry_font = font .. ' ' .. size
