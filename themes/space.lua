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

local act1 = 0x262222
local aqua = 0xb49544
local aqua0 = 0x74952d
local bg0 = 0x2e2b29
local bg1 = 0x262021
local bg2 = 0x140a10
local bg3 = 0x14080a
local bg4 = 0x3e3234
local blue = 0xd9b058
local blue0 = 0xd7974f
local blue1 = 0xdb9075
local cblk = 0xd5c1cb
local comp = 0xc36ec5
local cyan = 0xf0de28
local debug = 0xc8c8ff
local delim = 0xacba74
local fg = 0x5b5b5b
local fg0 = 0xcdcdcd
local fg1 = 0xb2b2b2
local fg2 = 0x8e8e8e
local fg3 = 0x727272
local fg4 = 0xba9a9a
local fg5 = 0x79505e
local float = 0xffb7b7
local green = 0x1db167
local green0 = 0xaea12a
local grey = 0x5c5044
local grey1 = 0x948276
local mat = 0x2fdc86
local meta = 0x66879f
local number = 0xe697e6
local orange = 0x5096d7
local orange0 = 0x5482e1
local purple = 0x654a54
local purple0 = 0xc56ebc
local purple1 = 0xfe98d6
local purple2 = 0xad5ba4
local purple3 = 0x7a4d5d
local purple4 = 0x3e3234
local red = 0x1f24f2
local red0 = 0x3c4ef5
local red1 = 0x7a53ce
local tc10 = 0x1f24f2
local tc12 = 0xa75ea1
local tc2 = 0x8764d2
local tc3 = 0xa5a835
local tc4 = 0x339fb8
local tc5 = 0xc58169
local tc6 = 0xa75ea1
local tc7 = 0x688628
local ui_activ = 0x7a4d5d
local war = 0x2f75dc
local yellow = 0x1d95b1
local yellow1 = 0x1cd1e5
local tc12 = 0xa75ea1

-- colors.bg = dark0_hard
colors.bg = bg0
colors.current_line_bg = grey
colors.selection_bg = purple
colors.selection_fg = fg4
colors.comment = fg5
colors.linenumbers_fg = fg5
colors.linenumbers_bg = bg1
colors.operator = fg2
colors.caret = meta
colors.highlight = base0
colors.regex = blue0
colors.label = red
colors.constant = red

-- colors.functions = aqua
colors.functions = blue0
-- colors.types = yellow
colors.types = purple2
colors.strings = aqua0
-- colors.keyword = purple2
colors.keyword = blue0
colors.number = green
colors.default = grey1

-- Predefined styles.
styles[view.STYLE_DEFAULT] = {
  font = font, size = size, fore = colors.default, back = colors.bg
}
styles[view.STYLE_LINENUMBER] = {fore = colors.linenumbers_fg, back = colors.linenumbers_bg}
styles[view.STYLE_BRACELIGHT] = {fore = colors.purple}
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
styles[lexer.CONSTANT] = {fore = delim, underline = true}
styles[lexer.EMBEDDED] = {fore = colors.purple}
styles[lexer.ERROR] = {fore = colors.red}
styles[lexer.FUNCTION] = {fore = green0}
-- styles[lexer.FUNCTION_BUILTIN] = {fore = colors.functions}
styles[lexer.FUNCTION_BUILTIN] = {fore = yellow}
styles[lexer.HEADING] = {fore = colors.purple}
styles[lexer.ITALIC] = {italic = true}
styles[lexer.KEYWORD] = {fore = colors.keyword}
styles[lexer.LABEL] = {fore = delim}
styles[lexer.LINK] = {underline = true}
styles[lexer.LIST] = {fore = colors.teal}
styles[lexer.NUMBER] = {fore = colors.number}
styles[lexer.OPERATOR] = {fore = colors.operator}
styles[lexer.PREPROCESSOR] = {fore = blue1, underline = true}
styles[lexer.REFERENCE] = {underline = true}
styles[lexer.REGEX] = {fore = purple2}
styles[lexer.STRING] = {fore = colors.strings}
styles[lexer.TAG] = {fore = colors.blue}
styles[lexer.TYPE] = {fore = colors.types}
styles[lexer.UNDERLINE] = {underline = true}
styles[lexer.VARIABLE_BUILTIN] = {fore = war}
-- styles[lexer.VARIABLE] = {fore = colors.red}
styles[lexer.KEYWORD .. '.ctl'] = {fore = red1}

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
view.element_color[view.ELEMENT_SELECTION_INACTIVE_BACK] = bg4
view.element_color[view.ELEMENT_SELECTION_INACTIVE_TEXT] = fg4
view.element_color[view.ELEMENT_SELECTION_ADDITIONAL_BACK] = colors.selection_bg
view.element_color[view.ELEMENT_SELECTION_ADDITIONAL_TEXT] = colors.selection_fg
view.element_color[view.ELEMENT_SELECTION_SECONDARY_BACK] = colors.selection_bg
view.element_color[view.ELEMENT_SELECTION_SECONDARY_TEXT] = colors.selection_fg
view.element_color[view.ELEMENT_WHITE_SPACE] = purple3
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
