local view, colors, styles = view, view.colors, view.styles

local bg_light = 0x6f5a00
local grey3 = 0x8e837d
local base03 = 0x362b00
local base02 = 0x423607
local base01 = 0x756e58
local base00 = 0x837b65
local base0 = 0x969483
local base1 = 0xa1a193
local base2 = 0xd5e8ee
local base3 = 0xe3f6fd
local yellow = 0x0089b5
local orange = 0x164bcb
local red = 0x2f32dc
local magenta = 0x8236d3
local violet = 0xc4716c
local blue = 0xd28b26
local cyan = 0x98a12a
local green = 0x009985

local dark0_hard = 0x21201d
local dark0_medium = 0x282828
local dark0_soft = 0x2f3032
local dark1 = 0x36383c
local dark2 = 0x454950
local dark3 = 0x545c66
local dark4 = 0x646f7c
local grey = 0x748392
local lightgrey = 0x8499a8
local light = 0x8ebfdf

local ghselbg = 0x665714

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
colors.purple = 0x990099
colors.magenta = magenta

colors.bg = dark0_hard
colors.current_line_bg = dark3
colors.selection_bg = ghselbg
colors.selection_fg = grey3
colors.comment = dark3
colors.linenumbers_fg = dark4
colors.linenumbers_bg = dark0_medium
colors.operator = base0
colors.caret = lightgrey
colors.highlight = base0
colors.regex = orange
colors.label = red
colors.constant = red

colors.functions = blue
colors.types = orange
colors.strings = yellow
colors.keyword = green
colors.number = cyan
colors.default = base01

-- Predefined styles.
styles[view.STYLE_DEFAULT] = {
  font = font, size = size, fore = colors.default, back = colors.bg
}
styles[view.STYLE_LINENUMBER] = {fore = colors.linenumbers_fg, back = colors.linenumbers_bg}
styles[view.STYLE_BRACELIGHT] = {fore = purple}
styles[view.STYLE_BRACEBAD] = {fore = colors.red}
styles[view.STYLE_INDENTGUIDE] = {fore = colors.operator}
styles[view.STYLE_CALLTIP] = {fore = colors.light_grey, back = colors.light_black}

-- Tag styles.
styles[lexer.ANNOTATION] = {fore = colors.purple}
styles[lexer.ATTRIBUTE] = {fore = colors.violet}
styles[lexer.BOLD] = {bold = true}
styles[lexer.CLASS] = {fore = colors.green}
styles[lexer.CODE] = {fore = colors.dark_grey, eolfilled = true}
styles[lexer.COMMENT] = {fore = colors.comment}
styles[lexer.CONSTANT] = {fore = cyan, underline = true}
styles[lexer.EMBEDDED] = {fore = colors.purple}
styles[lexer.ERROR] = {fore = colors.red}
styles[lexer.FUNCTION] = {fore = colors.violet}
styles[lexer.FUNCTION_BUILTIN] = {fore = colors.blue}
styles[lexer.HEADING] = {fore = colors.purple}
styles[lexer.ITALIC] = {italic = true}
styles[lexer.KEYWORD] = {fore = colors.green}
styles[lexer.LABEL] = {fore = cyan}
styles[lexer.LINK] = {underline = true}
styles[lexer.LIST] = {fore = colors.teal}
styles[lexer.NUMBER] = {fore = colors.teal}
styles[lexer.OPERATOR] = {fore = colors.operator}
styles[lexer.PREPROCESSOR] = {fore = colors.blue, underline = true}
styles[lexer.REFERENCE] = {underline = true}
styles[lexer.REGEX] = {fore = colors.orange}
styles[lexer.STRING] = {fore = colors.yellow}
styles[lexer.TAG] = {fore = colors.blue}
styles[lexer.TYPE] = {fore = colors.orange}
styles[lexer.UNDERLINE] = {underline = true}
styles[lexer.VARIABLE_BUILTIN] = {fore = colors.purple}
-- styles[lexer.VARIABLE] = {fore = colors.red}
styles[lexer.KEYWORD .. '.ctl'] = {fore = colors.magenta}

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
view.element_color[view.ELEMENT_CARET] = colors.caret
view.element_color[view.ELEMENT_CARET_ADDITIONAL] = colors.operator
view.element_color[view.ELEMENT_SELECTION_BACK] = colors.selection_bg
view.element_color[view.ELEMENT_SELECTION_TEXT] = colors.selection_fg
view.element_color[view.ELEMENT_SELECTION_INACTIVE_BACK] = dark1
view.element_color[view.ELEMENT_SELECTION_INACTIVE_TEXT] = grey
view.element_color[view.ELEMENT_SELECTION_ADDITIONAL_BACK] = colors.selection_bg
view.element_color[view.ELEMENT_SELECTION_ADDITIONAL_TEXT] = colors.selection_fg
view.element_color[view.ELEMENT_SELECTION_SECONDARY_BACK] = colors.selection_bg
view.element_color[view.ELEMENT_SELECTION_SECONDARY_TEXT] = colors.selection_fg
view.element_color[view.ELEMENT_WHITE_SPACE] = dark4
view.element_color[view.ELEMENT_CARET_LINE_BACK] = colors.current_line_bg

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
view.indic_fore[ui.find.INDIC_FIND] = colors.highlight
view.indic_alpha[ui.find.INDIC_FIND] = 32
view.indic_outline_alpha[ui.find.INDIC_FIND] = 128

view.indic_fore[textadept.editing.INDIC_HIGHLIGHT] = colors.highlight
view.indic_alpha[textadept.editing.INDIC_HIGHLIGHT] = 32
view.indic_outline_alpha[textadept.editing.INDIC_HIGHLIGHT] = 128


-- Call tips.
view.call_tip_fore_hlt = colors.blue

-- Long Lines.
view.edge_color = colors.light_black

-- Find & replace pane entries.
ui.find.entry_font = font .. ' ' .. size
