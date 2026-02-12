local view, colors, styles = view, view.colors, view.styles

local color = require('color')

local fgdef = color.rgb2bgr('d3c6aa')
local fgdefinv = color.rgb2bgr('212642')
local fgl = color.rgb2bgr('5c6a72')

-- hard

local bgdim = color.rgb2bgr('1e2326')
local bg0 = color.rgb2bgr('272e33')
local bg1 = color.rgb2bgr('2e383c')
local bg2 = color.rgb2bgr('374145')
local bg3 = color.rgb2bgr('414b50')
local bg4 = color.rgb2bgr('495156')
local bg5 = color.rgb2bgr('4f5b58')
local bgred = color.rgb2bgr('493b40')
local bgyellow = color.rgb2bgr('45443c')
local bggreen = color.rgb2bgr('3c4841')
local bgblue = color.rgb2bgr('384b55')
local bgpurple = color.rgb2bgr('463f48')
local bgvisual = color.rgb2bgr('4c3743')

-- medium

-- local bgdim = color.rgb2bgr('232a2e')
-- local bg0 = color.rgb2bgr('2d353b')
-- local bg1 = color.rgb2bgr('343f44')
-- local bg2 = color.rgb2bgr('3d484d')
-- local bg3 = color.rgb2bgr('475258')
-- local bg4 = color.rgb2bgr('4f585e')
-- local bg5 = color.rgb2bgr('56635f')
-- local bgred = color.rgb2bgr('514045')
-- local bgyellow = color.rgb2bgr('4d4c43')
-- local bggreen = color.rgb2bgr('425047')
-- local bgblue = color.rgb2bgr('3a515d')
-- local bgpurple = color.rgb2bgr('4a444e')
-- local bgvisual = color.rgb2bgr('543a48')

-- soft

-- local bgdim = color.rgb2bgr('293136')
-- local bg0 = color.rgb2bgr('333c43')
-- local bg1 = color.rgb2bgr('3a464c')
-- local bg2 = color.rgb2bgr('434f55')
-- local bg3 = color.rgb2bgr('4d5960')
-- local bg4 = color.rgb2bgr('555f66')
-- local bg5 = color.rgb2bgr('5d6b66')
-- local bgred = color.rgb2bgr('59464c')
-- local bgyellow = color.rgb2bgr('55544a')
-- local bggreen = color.rgb2bgr('48584e')
-- local bgblue = color.rgb2bgr('3f5865')
-- local bgpurple = color.rgb2bgr('4e4953')
-- local bgvisual = color.rgb2bgr('5c3f4f')

-- light colors (hard contrast)

local red = color.rgb2bgr('f85552')
local yellow = color.rgb2bgr('dfa000')
local green = color.rgb2bgr('8da101')
local blue = color.rgb2bgr('3a94c5')
local purple = color.rgb2bgr('df69ba')
local aqua = color.rgb2bgr('35a77c')
local orange = color.rgb2bgr('f57d26')
local grey0 = color.rgb2bgr('a6b0a0')
local grey1 = color.rgb2bgr('939f91')
local grey2 = color.rgb2bgr('829181')
local grey3 = color.rgb2bgr('708089')

-- dark colors (soft contrast)

-- local red = color.rgb2bgr('e57e80')
-- local yellow = color.rgb2bgr('dabc7f')
-- local green = color.rgb2bgr('a7c080')
-- local blue = color.rgb2bgr('7fbbb3')
-- local purple = color.rgb2bgr('d699b6')
-- local aqua = color.rgb2bgr('83c092')
-- local orange = color.rgb2bgr('e59875')
-- local grey0 = color.rgb2bgr('7a8478')
-- local grey1 = color.rgb2bgr('859289')
-- local grey2 = color.rgb2bgr('9da9a0')

-- Greyscale colors.
colors.black = color.rgb2bgr('000000')
colors.light_black = color.rgb2bgr('333333')
colors.dark_grey = color.rgb2bgr('666666')
colors.grey = color.rgb2bgr('999999')
colors.light_grey = color.rgb2bgr('CCCCCC')
colors.white = color.rgb2bgr('FFFFFF')

-- Normal colors.
colors.red = red
colors.orange = orange
colors.yellow = yellow
colors.lime = color.rgb2bgr('99CC00')
colors.green = green
colors.teal = aqua
colors.blue = blue
colors.purple = purple

-- Predefined styles.
styles[view.STYLE_DEFAULT] = {
  font = font,
  size = size,
  fore = grey3,
  back = bg0,
}
styles[view.STYLE_LINENUMBER] = { fore = bg4, back = bg0 }
styles[view.STYLE_BRACELIGHT] = { fore = fgdef, back = bg3 }
styles[view.STYLE_BRACEBAD] = { fore = colors.red }
styles[view.STYLE_INDENTGUIDE] = { fore = colors.dark_grey }
styles[view.STYLE_CALLTIP] = { fore = colors.light_grey, back = colors.light_black }
styles[view.STYLE_FOLDDISPLAYTEXT] = { fore = colors.dark_grey, back = bg0 }

-- Tag styles.
styles[lexer.ANNOTATION] = { fore = colors.purple }
styles[lexer.ATTRIBUTE] = { fore = colors.yellow }
styles[lexer.BOLD] = { bold = true }
styles[lexer.CLASS] = { fore = colors.yellow }
styles[lexer.CODE] = { fore = bg2, eol_filled = true }
styles[lexer.COMMENT] = { fore = bg5 }
styles[lexer.CONSTANT] = { fore = colors.orange }
styles[lexer.EMBEDDED] = { fore = colors.yellow }
styles[lexer.ERROR] = { fore = colors.red }
styles[lexer.FUNCTION] = { fore = colors.blue }
-- styles[lexer.FUNCTION_BUILTIN] = {fore = colors.blue}
styles[lexer.HEADING] = { fore = colors.purple }
styles[lexer.ITALIC] = { italic = true }
styles[lexer.KEYWORD] = { fore = colors.red }
styles[lexer.LABEL] = { fore = colors.yellow }
styles[lexer.LINK] = { underline = true }
styles[lexer.LIST] = { fore = bg2 }
styles[lexer.NUMBER] = { fore = colors.purple }
styles[lexer.OPERATOR] = { fore = grey2 }
styles[lexer.PREPROCESSOR] = { fore = colors.yellow }
styles[lexer.REFERENCE] = { underline = true }
styles[lexer.REGEX] = { fore = colors.teal }
styles[lexer.STRING] = { fore = colors.green }
styles[lexer.TAG] = { fore = colors.blue }
styles[lexer.TYPE] = { fore = colors.teal }
styles[lexer.UNDERLINE] = { underline = true }
styles[lexer.VARIABLE_BUILTIN] = { fore = colors.yellow }
styles[lexer.TYPE .. '.custom'] = { fore = colors.teal }

-- CSS.
styles.property = styles[lexer.ATTRIBUTE]
-- styles.pseudoclass = {}
-- styles.pseudoelement = {}
-- Diff.
styles.addition = { fore = colors.green }
styles.deletion = { fore = colors.red }
styles.change = { fore = colors.yellow }
-- HTML.
styles.tag_unknown = styles.tag .. { italic = true }
styles.attribute_unknown = styles.attribute .. { italic = true }
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
styles.error_indent = { back = colors.red }

-- Caret and Selection Styles.
view.element_color[view.ELEMENT_CARET] = fgdef
view.element_color[view.ELEMENT_CARET_LINE_BACK] = bg4

ui.command_entry.element_color[view.ELEMENT_CARET] = fgdef

view.element_color[view.ELEMENT_SELECTION_BACK] = bgblue
view.element_color[view.ELEMENT_SELECTION_TEXT] = grey1

view.element_color[view.ELEMENT_SELECTION_INACTIVE_BACK] = bgyellow
view.element_color[view.ELEMENT_SELECTION_INACTIVE_TEXT] = grey1

view.element_color[view.ELEMENT_CARET_ADDITIONAL] = grey2
view.element_color[view.ELEMENT_SELECTION_ADDITIONAL_BACK] = bggreen
view.element_color[view.ELEMENT_SELECTION_ADDITIONAL_TEXT] = grey1

view.element_color[view.ELEMENT_SELECTION_SECONDARY_BACK] = bgblue
view.element_color[view.ELEMENT_SELECTION_SECONDARY_TEXT] = grey1

view.element_color[view.ELEMENT_WHITE_SPACE] = bg4

-- Fold Margin.
view:set_fold_margin_color(true, bg0)
view:set_fold_margin_hi_color(true, bg0)

-- Markers.
-- view.marker_fore[textadept.bookmarks.MARK_BOOKMARK] = colors.black
view.marker_back[textadept.bookmarks.MARK_BOOKMARK] = colors.blue
-- view.marker_fore[textadept.run.MARK_WARNING] = colors.black
view.marker_back[textadept.run.MARK_WARNING] = colors.yellow
-- view.marker_fore[textadept.run.MARK_ERROR] = colors.black
view.marker_back[textadept.run.MARK_ERROR] = colors.red
for i = view.MARKNUM_FOLDEREND, view.MARKNUM_FOLDEROPEN do -- fold margin
  view.marker_fore[i] = bg0
  view.marker_back[i] = colors.dark_grey
  view.marker_back_selected[i] = colors.light_grey
end

-- Indicators.
view.indic_fore[ui.find.INDIC_FIND] = grey2
view.indic_alpha[ui.find.INDIC_FIND] = 32
view.indic_outline_alpha[ui.find.INDIC_FIND] = 128

view.indic_fore[textadept.editing.INDIC_HIGHLIGHT] = grey2
view.indic_alpha[textadept.editing.INDIC_HIGHLIGHT] = 32
view.indic_outline_alpha[textadept.editing.INDIC_HIGHLIGHT] = 128

-- Call tips.
view.call_tip_fore_hlt = colors.blue

-- Long Lines.
view.edge_color = colors.light_black

-- Find & replace pane entries.
ui.find.entry_font = font .. ' ' .. size
