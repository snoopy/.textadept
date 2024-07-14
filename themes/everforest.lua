local view, colors, styles = view, view.colors, view.styles

local f_def = 0x726a5c

local f_bg_d = 0x2e2a23
local f_bg0 = 0x3b352d
local f_bg_h = 0x26231e
local f_bg_m = 0x2e2a23
local f_bg_s = 0x363129

local f_g1 = 0xa0b0a6
local f_g2 = 0x919f93
local f_g3 = 0x819182
local f_g4 = 0x898070
local f_g5 = 0x899285
local f_g6 = 0x4d483d
local f_g7 = 0x585247
local f_g8 = 0x5e584f
local f_g9 = 0x665f55

local f_dark = 0x434c4d
local f_dark2 = 0x5f6356
local f_dark3 = 0x78847a
local f_dark4 = 0x475042
local f_dark5 = 0x4a5455
local f_dark6 = 0x545c66

local f_red_s = 0x6868e6
local f_green_s = 0x59b293

local f_red = 0x5255f8
local f_orange = 0x267df5
local f_yellow = 0x00a0df
local f_green = 0x01a18d
local f_aqua = 0x7ca735
local f_blue = 0xc5943a
local f_purple = 0xba69df

-- Greyscale colors.
colors.black = 0x000000
colors.light_black = 0x333333
colors.dark_grey = 0x666666
colors.grey = 0x999999 -- unused
colors.light_grey = 0xCCCCCC
colors.white = 0xFFFFFF -- unused

-- Normal colors.
colors.red = f_red
colors.orange = f_orange
colors.yellow = f_yellow
colors.lime = 0x00CC99
colors.green = f_green
colors.teal = f_aqua
colors.blue = f_blue
colors.purple = f_purple

-- Predefined styles.
styles[view.STYLE_DEFAULT] = {
  font = font, size = size, fore = f_g4, back = f_bg0
}
styles[view.STYLE_LINENUMBER] = {fore = f_dark2, back = f_bg0}
styles[view.STYLE_BRACELIGHT] = {fore = colors.orange}
styles[view.STYLE_BRACEBAD] = {fore = colors.red}
styles[view.STYLE_INDENTGUIDE] = {fore = f_g4}
styles[view.STYLE_CALLTIP] = {fore = colors.light_grey, back = colors.light_black}

-- Tag styles.
styles[lexer.ANNOTATION] = {fore = colors.purple}
styles[lexer.ATTRIBUTE] = {fore = colors.yellow}
styles[lexer.BOLD] = {bold = true}
styles[lexer.CLASS] = {fore = colors.yellow}
styles[lexer.CODE] = {fore = f_dark, eol_filled = true}
styles[lexer.COMMENT] = {fore = f_g9}
styles[lexer.CONSTANT] = {fore = colors.orange}
styles[lexer.EMBEDDED] = {fore = colors.yellow}
styles[lexer.ERROR] = {fore = colors.red}
styles[lexer.FUNCTION] = {fore = colors.blue}
-- styles[lexer.FUNCTION_BUILTIN] = {fore = colors.blue}
styles[lexer.HEADING] = {fore = colors.purple}
styles[lexer.ITALIC] = {italic = true}
styles[lexer.KEYWORD] = {fore = colors.red}
styles[lexer.LABEL] = {fore = colors.yellow}
styles[lexer.LINK] = {underline = true}
styles[lexer.LIST] = {fore = f_dark}
styles[lexer.NUMBER] = {fore = colors.purple}
styles[lexer.OPERATOR] = {fore = f_g5}
styles[lexer.PREPROCESSOR] = {fore = colors.yellow}
styles[lexer.REFERENCE] = {underline = true}
styles[lexer.REGEX] = {fore = colors.teal}
styles[lexer.STRING] = {fore = colors.green}
styles[lexer.TAG] = {fore = colors.blue}
styles[lexer.TYPE] = {fore = colors.teal}
styles[lexer.UNDERLINE] = {underline = true}
styles[lexer.VARIABLE_BUILTIN] = {fore = colors.yellow}
styles[lexer.TYPE .. '.custom'] = {fore = colors.teal}

-- CSS.
styles.property = styles[lexer.ATTRIBUTE]
-- styles.pseudoclass = {}
-- styles.pseudoelement = {}
-- Diff.
styles.addition = {fore = colors.green}
styles.deletion = {fore = colors.red}
styles.change = {fore = colors.yellow}
-- HTML.
styles.tag_unknown = styles.tag .. {italic = true}
styles.attribute_unknown = styles.attribute .. {italic = true}
-- Latex, TeX, and Texinfo.
styles.command = styles[lexer.KEYWORD]
styles.command_section = styles[lexer.HEADING]
styles.environment = styles[lexer.TYPE]
styles.environment_math = styles[lexer.NUMBER]
-- Makefile.
-- styles.target = {}
-- Markdown.
-- styles.hr = {}
-- Python.
styles.keyword_soft = {}
-- XML.
-- styles.cdata = {}
-- YAML.
styles.error_indent = {back = colors.red}

-- Caret and Selection Styles.
view.element_color[view.ELEMENT_CARET] = f_g1
view.element_color[view.ELEMENT_CARET_LINE_BACK] = f_g9

ui.command_entry.element_color[view.ELEMENT_CARET] = f_g1

view.element_color[view.ELEMENT_SELECTION_BACK] = f_g4
view.element_color[view.ELEMENT_SELECTION_TEXT] = f_bg_d

view.element_color[view.ELEMENT_SELECTION_INACTIVE_BACK] = f_g9
view.element_color[view.ELEMENT_SELECTION_INACTIVE_TEXT] = f_bg_d

view.element_color[view.ELEMENT_CARET_ADDITIONAL] = f_g2
view.element_color[view.ELEMENT_SELECTION_ADDITIONAL_BACK] = f_g3
view.element_color[view.ELEMENT_SELECTION_ADDITIONAL_TEXT] = f_bg_d

view.element_color[view.ELEMENT_SELECTION_SECONDARY_BACK] = f_g4
view.element_color[view.ELEMENT_SELECTION_SECONDARY_TEXT] = f_bg_d

view.element_color[view.ELEMENT_WHITE_SPACE] = f_g4

-- Markers.
-- view.marker_fore[textadept.bookmarks.MARK_BOOKMARK] = colors.black
view.marker_back[textadept.bookmarks.MARK_BOOKMARK] = colors.blue
-- view.marker_fore[textadept.run.MARK_WARNING] = colors.black
view.marker_back[textadept.run.MARK_WARNING] = colors.yellow
-- view.marker_fore[textadept.run.MARK_ERROR] = colors.black
view.marker_back[textadept.run.MARK_ERROR] = colors.red
for i = view.MARKNUM_FOLDEREND, view.MARKNUM_FOLDEROPEN do -- fold margin
  view.marker_fore[i] = colors.black
  view.marker_back[i] = colors.dark_grey
  view.marker_back_selected[i] = colors.light_grey
end

-- Indicators.
view.indic_fore[ui.find.INDIC_FIND] = f_g1
view.indic_alpha[ui.find.INDIC_FIND] = 32
view.indic_outline_alpha[ui.find.INDIC_FIND] = 128

view.indic_fore[textadept.editing.INDIC_HIGHLIGHT] = f_g1
view.indic_alpha[textadept.editing.INDIC_HIGHLIGHT] = 32
view.indic_outline_alpha[textadept.editing.INDIC_HIGHLIGHT] = 128


-- Call tips.
view.call_tip_fore_hlt = colors.blue

-- Long Lines.
view.edge_color = colors.light_black

-- Find & replace pane entries.
ui.find.entry_font = font .. ' ' .. size
