view:set_theme('solarbox', { font = 'JetBrains Mono NL Medium', size = 15 })

buffer.use_tabs = false
buffer.tab_width = 4
buffer.tab_indents = true
buffer.back_space_un_indents = true
buffer.eol_mode = buffer.EOL_LF

-- disable menubar, tabs and scrollbars
events.connect(events.INITIALIZED, function() textadept.menu.menubar = nil end)
ui.tabs = false
view.h_scroll_bar = false
view.v_scroll_bar = false
-- disable folding and fold margin
view.property['fold'] = 0
view.margin_width_n[3] = 0

view.caret_period = 0
view.caret_style = view.CARETSTYLE_BLOCK
view.caret_line_frame = 1

view.edge_column = 100
view.edge_color = 0xcccccc

view.wrap_indent_mode = view.WRAPINDENT_DEEPINDENT
view.indentation_guides = buffer.IV_LOOKBOTH
view.whitespace_size = 5

textadept.editing.strip_trailing_spaces = true
io.ensure_final_newline = true

-- highlight all search results and all selections
ui.find.highlight_all_matches = true
textadept.editing.highlight_words = textadept.editing.HIGHLIGHT_SELECTED
-- center results when searching
events.connect(events.FIND_RESULT_FOUND, function() view:vertical_center_caret() end)

-- autocompletion settings
buffer.auto_c_auto_hide = true
buffer.auto_c_cancel_at_start = false
buffer.auto_c_case_insensitive_behavior = buffer.CASEINSENSITIVEBEHAVIOR_IGNORECASE
buffer.auto_c_choose_single = false
buffer.auto_c_ignore_case = true
buffer.auto_c_max_height = 15
buffer.auto_c_multi = buffer.MULTIAUTOC_EACH

-- paste into every selection when multiple selections are active
buffer.multi_paste = buffer.MULTIPASTE_EACH

lexer.detect_extensions.conf = 'ini'
lexer.detect_extensions.csv = 'ini'
lexer.detect_extensions.gitconfig = 'ini'
lexer.detect_extensions.cmake = 'cmake'
lexer.detect_patterns.cmake = 'cmake'

textadept.editing.brace_matches[string.byte('<')] = true
textadept.editing.brace_matches[string.byte('>')] = true
textadept.editing.auto_pairs = {}
textadept.editing.typeover_chars = {}

textadept.run.compile_commands.cpp = 'g++ -std=c++20 -O2 "%f"'

events.connect(events.LEXER_LOADED, function(name)
  if name == 'yaml' or
      name == 'lua' or
      name == 'html' then
    buffer.use_tabs = false
    buffer.tab_width = 2
  elseif name == 'python' then
    buffer.use_tabs = false
    buffer.tab_width = 4
  end
  -- dont strip trailing spaces when doing markdown
  textadept.editing.strip_trailing_spaces = lexer ~= 'markdown'
end)

events.connect(events.FILE_CHANGED, function()
  buffer:reload()
  ui.statusbar_text = 'WARNING: Buffer was modified externally and has been reloaded!'
  return true
end, 1)

events.connect(events.FILE_AFTER_SAVE, function(filename)
  if buffer:get_lexer() == 'cpp' then
    os.spawn('clang-format -i -style=file -fallback-style=none "' .. filename .. '"'):wait()
    buffer:reload()
  end
end)

lfs.default_filter[#lfs.default_filter + 1] = '!/build.*$'
lfs.default_filter[#lfs.default_filter + 1] = '!/extern%a*$'

io.quick_open_max = 10000

-- functions

local function m(labels)
  local menu = textadept.menu.menubar
  for label in labels:gmatch('[^/]+') do menu = menu[_L[label]] end
  return menu[2]
end

local function add_braces(style, append, tab)
  buffer:begin_undo_action()
  if style == 'allman' then
    buffer:line_end()
    buffer:new_line()
    buffer:add_text('{')
    buffer:new_line()
  elseif style == 'kr' then
    buffer:line_end()
    buffer:add_text(' {')
    buffer:new_line()
  end
  buffer:new_line()
  buffer:add_text('}' .. append)
  buffer:line_up()
  if tab then
    buffer:tab()
  end
  buffer:end_undo_action()
end

local function enclose_or_add(left, right)
  buffer:begin_undo_action()
  for i = 1, buffer.selections do
    local s, e = buffer.selection_n_start[i], buffer.selection_n_end[i]
    buffer:set_target_range(s, e)
    buffer:replace_target(left .. buffer.target_text .. right)
    buffer.selection_n_start[i] = buffer.target_start + #left
    buffer.selection_n_end[i] = buffer.target_end - #right
  end
  buffer:end_undo_action()
end

local function insert_text_multi(text)
  buffer:begin_undo_action()
  for i = 1, buffer.selections do
    local s, e = buffer.selection_n_start[i], buffer.selection_n_end[i]
    buffer:set_target_range(s, e)
    buffer:replace_target(text .. buffer.target_text)
    buffer.selection_n_start[i] = buffer.target_end
    buffer.selection_n_end[i] = buffer.target_end
  end
  buffer:end_undo_action()
end

local function clear_indicators()
  buffer.indicator_current = ui.find.INDIC_FIND
  buffer:indicator_clear_range(1, buffer.length)
  buffer.indicator_current = textadept.editing.INDIC_HIGHLIGHT
  buffer:indicator_clear_range(1, buffer.length)
end

local function select_matching()
  local target = buffer:brace_match(buffer.current_pos, 0)
  if target < buffer.current_pos then
    buffer:set_selection(buffer.current_pos, target + 1)
  else
    buffer:set_selection(buffer.current_pos + 1, target)
  end
end

local function custom_comment()
  local comment = textadept.editing.comment_string[buffer:get_lexer(true)] or buffer.property['scintillua.comment']
  local prefix, suffix = comment:match('^([^|]+)|?([^|]*)$')
  if not prefix then return end

  local prefix_esc = ''
  for c in prefix:gmatch('.') do
    prefix_esc = prefix_esc .. '%' .. c
  end
  prefix = prefix .. ' '

  local current_line = buffer:get_line(buffer.line_from_position(buffer.current_pos))
  if buffer.selection_empty and current_line:match('^%s*$') then
    buffer:insert_text(buffer.current_pos, prefix)
    buffer:goto_pos(buffer.current_pos + #prefix)
    return
  end

  local anchor, pos = buffer.selection_start, buffer.selection_end
  local s, e = buffer:line_from_position(anchor), buffer:line_from_position(pos)
  local ignore_last_line = s ~= e and pos == buffer:position_from_line(e)
  anchor, pos = buffer.line_end_position[s] - anchor, buffer.length + 1 - pos
  local column = math.huge

  buffer:begin_undo_action()
  for line = s, not ignore_last_line and e or e - 1 do
    local full_line = buffer:get_line(line)
    if full_line:match('^%s*$') then goto continue end

    local p = buffer.line_indent_position[line]

    local uncomment = full_line:match('^%s*(' .. prefix_esc .. '%s?)')
    if uncomment then uncomment = uncomment:gsub('\n*$', '') end

    if not uncomment then
      buffer:insert_text(p, prefix)
      if suffix ~= '' then buffer:insert_text(buffer.line_end_position[line], suffix) end
    else
      buffer:delete_range(p, #uncomment)
      if suffix ~= '' then
        p = buffer.line_end_position[line]
        buffer:delete_range(p - #suffix, #suffix)
      end
    end

    if line == s then anchor = anchor + #suffix * (uncomment and -1 or 1) end
    if line == e then pos = pos + #suffix * (uncomment and -1 or 1) end
    ::continue::
  end
  buffer:end_undo_action()

  anchor, pos = buffer.line_end_position[s] - anchor, buffer.length + 1 - pos
  -- Keep the anchor and caret on the first line as necessary.
  local start_pos = buffer:position_from_line(s)
  anchor, pos = math.max(anchor, start_pos), math.max(pos, start_pos)
  if s ~= e then
    buffer:set_sel(anchor, pos)
  else
    buffer:goto_pos(pos)
  end
end

-- keybinds

-- unbind some defaults
keys['ctrl+alt+\\'] = nil
keys['ctrl+r'] = nil
keys['ctrl+q'] = nil
keys['ctrl+f'] = nil
keys['ctrl+p'] = nil
keys['ctrl+o'] = nil
keys['ctrl+d'] = nil
keys['ctrl+u'] = nil

local textredux = require('textredux')
textredux.hijack()
local ctags_redux = require('ctags_redux')
local util = require('util')

local function dispatch(case)
  local switch = {}

  switch['open'] = textredux.fs.open_file
  switch['switchbuffer'] = textredux.buffer_list.show
  switch['saveas'] = textredux.fs.save_buffer_as
  -- switch['recent'] = textredux.core.filteredlist.wrap(io.open_recent_file)
  -- switch['lexer'] = textredux.core.filteredlist.wrap(m('Buffer/Select Lexer...'))
  -- switch['bookmarks'] = textredux.core.filteredlist.wrap(textadept.bookmarks.goto_mark)
  -- switch['ctags_init'] = ctags_redux.init_ctags
  -- switch['ctags_local'] = ctags_redux.find_local
  -- switch['ctags_global'] = ctags_redux.find_global
  -- switch['ctags_back'] = ctags_redux.go_back

  -- switch['open'] = io.open_file
  -- switch['switchbuffer'] = ui.switch_buffer
  -- switch['saveas'] = buffer.save_as
  switch['recent'] = io.open_recent_file
  switch['lexer'] = m('Buffer/Select Lexer...')
  switch['bookmarks'] = textadept.bookmarks.goto_mark
  switch['ctags_init'] = function()end
  switch['ctags_local'] = function()end
  switch['ctags_global'] = function()end
  switch['ctags_back'] = function()end

  return switch[case]
end

events.connect(events.CHAR_ADDED, function(code)
  if code >= 48 and code <= 57 or code >= 65 and code <= 90 or code >= 97 and code <= 122 or code == 95 then
    textadept.editing.autocomplete('word')
    if buffer:auto_c_active() then
      return
    end
    textadept.editing.autocomplete(buffer:get_lexer(true))
  end
end)

events.connect(events.KEYPRESS, function(code)
  if buffer:auto_c_active() and code ~= 65505 then
    buffer:auto_c_cancel()
  end
end)

keys['\n'] = function()
  if buffer:auto_c_active() then
    buffer:auto_c_complete()
    return true
  end
  return false
end

keys.up = function()
  if buffer:auto_c_active() then
    buffer:auto_c_cancel()
    return false
  end
  return false
end

keys.down = function()
  if buffer:auto_c_active() then
    buffer:auto_c_cancel()
    return false
  end
  return false
end

keys['home'] = function()
  if buffer:auto_c_active() then
    buffer:auto_c_cancel()
    return false
  end
  return false
end

keys['end'] = function()
  if buffer:auto_c_active() then
    buffer:auto_c_cancel()
    return false
  end
  return false
end

-- select next autosuggestion with TAB
keys['\t'] = function()
  if buffer:auto_c_active() then
    buffer:line_down()
    return
  end
  return false -- def
end

-- select prev autosuggestion with shift+TAB
keys['shift+\t'] = function()
  if buffer:auto_c_active() then
    buffer:line_up()
    return
  end
  return false -- def
end

keys['shift+esc'] = quit

-- c++
keys['ctrl+f1'] = dispatch('ctags_local')
keys['ctrl+f2'] = dispatch('ctags_global')
keys['ctrl+f8'] = dispatch('ctags_back')
keys.f4 = util.toggle_header

-- editing

keys.f8 = buffer.undo
keys.f5 = buffer.redo

keys['ctrl+r'] = textadept.editing.paste_reindent

keys.f2 = function()
  clear_indicators()
  textadept.editing.select_word()
  view:scroll_caret()
end

keys['shift+f2'] = function()
  buffer:drop_selection_n(buffer.selections)
  view:scroll_caret()
end

keys['alt+f2'] = function()
  clear_indicators()
  textadept.editing.select_word(true)
end

keys['alt+4'] = function()
  enclose_or_add('<', '>')
end
keys['alt+3'] = function()
  enclose_or_add('(', ')')
end
keys['alt+2'] = function()
  enclose_or_add('[', ']')
end
keys['alt+1'] = function()
  enclose_or_add('{', '}')
end
keys['alt+s'] = function()
  enclose_or_add("'", "'")
end
keys['alt+d'] = function()
  enclose_or_add('"', '"')
end
keys['alt+l'] = function()
  enclose_or_add('/', '/')
end
keys['alt+c'] = custom_comment
keys['alt+f'] = buffer.line_delete
keys['alt+v'] = buffer.line_duplicate
keys['alt+r'] = function()
  buffer:vc_home()
  local _, caret_pos = buffer:get_cur_line()
  if caret_pos == 1 then
    buffer:vc_home()
  end
  buffer:line_end_extend()
  buffer:delete_back()
end
keys['alt+q'] = buffer.del_word_left
keys['alt+e'] = buffer.del_word_right
keys['alt+w'] = function()
  textadept.editing.select_word()
  local s, e = buffer.selection_start, buffer.selection_end
  buffer:delete_range(s, e - s)
end

keys['alt+a'] = function()
  if buffer.selection_empty then
    buffer:vc_home()
    local _, caret_pos = buffer:get_cur_line()
    if caret_pos == 1 then
      buffer:vc_home()
    end
    buffer:line_end_extend()
  else
    buffer:line_down_extend()
    buffer:line_end_extend()
  end
  buffer:copy()
end

-- delete line above current line
keys['alt+\b'] = function()
  buffer:line_up()
  buffer:line_delete()
end

-- add ; to end of line
keys['alt+,'] = function()
  buffer:begin_undo_action()
  buffer:line_end_display()
  buffer:add_text(';')
  buffer:end_undo_action()
end

-- add m to end of line
keys['alt+m'] = function()
  buffer:begin_undo_action()
  buffer:line_end_display()
  buffer:add_text(',')
  buffer:end_undo_action()
end

-- insert and go to new line
keys['ctrl+\n'] = function()
  buffer:line_end_display()
  buffer:new_line()
end

-- movement

keys.f1 = dispatch('switchbuffer')

keys.f3 = function()
  clear_indicators()
  ui.find.focus({ in_files = false, incremental = true, regex = false, match_case = false})
end

keys['shift+f3'] = function()
  clear_indicators()
  ui.find.focus({ in_files = true, incremental = false, regex = false, match_case = false })
end

keys.f11 = function()
  util.goto_nearest_occurrence(true)
  buffer:vertical_center_caret()
end

keys.f12 = function()
  util.goto_nearest_occurrence(false)
  buffer:vertical_center_caret()
end

-- move to previous space
keys['alt+left'] = function()
  util.goto_space(true)
end

-- move to next empty space
keys['alt+right'] = function()
  util.goto_space(false)
end

keys['ctrl+alt+right'] = buffer.word_part_right
keys['ctrl+alt+left'] = buffer.word_part_left

-- move to end of next line
keys['alt+shift+\n'] = function()
  buffer:line_down()
  buffer:line_end()
end

-- go to prev line and insert newline
keys['alt+\n'] = function()
  buffer:begin_undo_action()
  buffer:vc_home()
  local _, caret_pos = buffer:get_cur_line()
  if caret_pos == 1 then
    buffer:vc_home()
  end
  buffer:new_line()
  buffer:line_up()
  buffer:end_undo_action()
end

keys['ctrl+ '] = function()
  if buffer.char_at[buffer.current_pos] ~= 0xA then
    buffer:char_right()
  end
end

keys['ctrl+pgdn'] = function()
  view:goto_buffer(1)
end
keys['ctrl+pgup'] = function()
  view:goto_buffer(-1)
end
keys['ctrl+up'] = function()
  buffer:line_scroll(0, -10)
end
keys['ctrl+down'] = function()
  buffer:line_scroll(0, 10)
end
keys['alt+home'] = buffer.scroll_to_start
keys['alt+end'] = buffer.scroll_to_end

keys['alt+up'] = function()
  buffer:para_up()
  buffer:vc_home()
end

keys['alt+down'] = function()
  buffer:para_down()
  buffer:vc_home()
end

-- move cursor to start/end of visible screen
keys['pgup'] = function()
  buffer.stuttered_page_up()
end
keys['pgdn'] = function()
  buffer.stuttered_page_down()
end

-- center cursor
keys['ins'] = function()
  if buffer.line_count < buffer.lines_on_screen then
    buffer:goto_line(math.floor(buffer.line_count / 2))
  else
    buffer:goto_line(math.floor(buffer.first_visible_line + buffer.lines_on_screen / 2))
  end
end

keys.f6 = util.last_buffer

keys.f7 = function()
  ui.goto_view(1)
end

keys['shift+f7'] = function()
  ui.goto_view(-1)
end

keys['home'] = function()
  buffer.vc_home_wrap()
end

keys['end'] = function()
  buffer.line_end_wrap()
end

local hydra = require('hydra')

local insert_hydra = hydra.create({
  {
    key = 'n',
    help = '\\n',
    action = function()
      insert_text_multi('\\n')
    end,
    persistent = true,
  },
  {
    key = 'm',
    help = 'allman',
    action = function()
      add_braces('allman', '', true)
    end,
  },
  {
    key = 'alt+m',
    help = 'allman;',
    action = function()
      add_braces('allman', ';', true)
    end,
  },
  {
    key = 'k',
    help = 'kr',
    action = function()
      add_braces('kr', '', true)
    end,
  },
  {
    key = 'alt+k',
    help = 'kr;',
    action = function()
      add_braces('kr', ';', true)
    end,
  },
  {
    key = 's',
    help = 'std::',
    action = function()
      insert_text_multi('std::')
    end,
  },
  {
    key = 'i',
    help = 'include',
    action = function()
      insert_text_multi('#include <>')
      buffer:char_left()
    end,
  },
  {
    key = 'l',
    help = 'include local',
    action = function()
      insert_text_multi('#include ""')
      buffer:char_left()
    end,
  },
  { key = 'p', help = 'namespace', action = util.insert_namespace },
})

local edit_hydra = hydra.create({
  {
    key = 'up',
    help = 'move up',
    action = buffer.move_selected_lines_up,
    persistent = true,
  },
  {
    key = 'down',
    help = 'move down',
    action = buffer.move_selected_lines_down,
    persistent = true,
  },
  {
    key = 'home',
    help = 'del start',
    action = function()
      buffer:vc_home_extend()
      buffer:delete_range(buffer.selection_start, buffer.selection_end - buffer.selection_start)
    end,
  },
  {
    key = 'end',
    help = 'del end',
    action = buffer.del_line_right,
  },
  {
    key = 'p',
    help = 'del para',
    action = function()
      textadept.editing.select_paragraph()
      buffer:delete_back()
    end,
    persistent = true,
  },
})

local select_hydra = hydra.create({
  {
    key = '1',
    help = '{}',
    action = function()
      textadept.editing.select_enclosed('{', '}')
    end,
  },
  {
    key = '2',
    help = '[]',
    action = function()
      textadept.editing.select_enclosed('[', ']')
    end,
  },
  {
    key = '3',
    help = '()',
    action = function()
      textadept.editing.select_enclosed('(', ')')
    end,
  },
  {
    key = '4',
    help = '<>',
    action = function()
      textadept.editing.select_enclosed('<', '>')
    end,
  },
  {
    key = 's',
    help = "''",
    action = function()
      textadept.editing.select_enclosed("'", "'")
    end,
  },
  {
    key = 'd',
    help = '""',
    action = function()
      textadept.editing.select_enclosed('"', '"')
    end,
  },
  {
    key = ' ',
    help = 'spaces',
    action = function()
      textadept.editing.select_enclosed(' ', ' ')
    end,
  },
  {
    key = 'i',
    help = '/* */',
    action = function()
      textadept.editing.select_enclosed('/*', '*/')
    end,
  },
  {
    key = 'x',
    help = 'custom',
    action = function()
      local value, button = ui.dialogs.input({
        title = 'Select between custom',
        text = '',
        button1 = 'OK',
        button2 = 'Cancel',
        return_button = true,
      })
      if button == 1 then
        textadept.editing.select_enclosed(value, value)
      end
    end,
  },
  {
    key = 'm',
    help = 'matching',
    action = function()
      select_matching()
    end,
  },
  { key = 'p', help = 'paragraph', action = textadept.editing.select_paragraph },
  { key = 'right', help = 'sel right', action = buffer.word_right_extend, persistent = true },
  { key = 'left', help = 'sel left', action = buffer.word_left_extend, persistent = true },
  {
    key = 'home',
    help = 'to start',
    action = function()
      buffer:vc_home_extend()
      buffer:copy()
    end,
  },
  {
    key = 'end',
    help = 'to end',
    action = function()
      buffer:line_end_extend()
      buffer:copy()
    end,
  },
  {
    key = 'up',
    help = 'rect up',
    action = buffer.line_up_rect_extend,
    persistent = true,
  },
  {
    key = 'down',
    help = 'rect down',
    action = buffer.line_down_rect_extend,
    persistent = true,
  },
  {
    key = 'pgup',
    help = 'para up',
    action = buffer.para_up_extend,
    persistent = true,
  },
  {
    key = 'pgdn',
    help = 'para down',
    action = buffer.para_down_extend,
    persistent = true,
  },
  {
    key = 'h',
    help = 'buffer start',
    action = buffer.document_start_extend,
  },
  {
    key = 'e',
    help = 'buffer end',
    action = buffer.document_end_extend,
  },
  {
    key = 'a',
    help = 'buffer',
    action = buffer.select_all,
  },
})

local selection_hydra = hydra.create({
  { key = 'u', help = 'upper case', action = buffer.upper_case },
  { key = 'l', help = 'lower case', action = buffer.lower_case },
  {
    key = 's',
    help = 'sort',
    action = function()
      local lines = {}
      local line_nr = buffer:line_from_position(buffer.selection_start)
      local last_line = buffer:line_from_position(buffer.selection_end)
      while line_nr <= last_line do
        local line = buffer:get_line(line_nr)
        line = line:match('^%s*(.-)%s*$')
        table.insert(lines, line)
        line_nr = line_nr + 1
      end
      table.sort(lines)
      buffer:begin_undo_action()
      buffer:delete_back()
      buffer:add_text(table.concat(lines, '\n'))
      buffer:end_undo_action()
    end,
  },
  {
    key = 't',
    help = 'trim both',
    action = function()
      if buffer.selection_empty then
        return
      end
      buffer:begin_undo_action()
      for i = 1, buffer.selections do
        local s, e = buffer.selection_n_start[i], buffer.selection_n_end[i]
        buffer:delete_range(s - 1, 1)
        buffer:delete_range(e - 1, 1)
      end
      buffer:end_undo_action()
    end,
    persistent = true,
  },
  {
    key = ' ',
    help = 'enclose spaces',
    action = function()
      enclose_or_add(' ', ' ')
    end,
    persistent = true,
  },
  {
    key = 'i',
    help = 'enclose /* */',
    action = function()
      textadept.editing.enclose('/* ', ' */')
    end,
  },
  {
    key = 'b',
    help = 'enclose braces',
    action = function()
      local s = buffer.selection_start
      local e = buffer.selection_end
      local line_nr = buffer:line_from_position(buffer.selection_start)
      local last_line = buffer:line_from_position(buffer.selection_end)
      line_nr = line_nr + 1
      last_line = last_line + 1

      buffer:begin_undo_action()

      buffer:goto_pos(e)
      buffer:line_end()
      buffer:new_line()
      buffer:add_text('}')

      buffer:goto_pos(s)
      buffer:new_line()
      buffer:line_up()
      buffer:add_text('{')

      while line_nr <= last_line do
        buffer:goto_line(line_nr)
        buffer:vc_home()
        buffer:tab()
        line_nr = line_nr + 1
      end

      buffer:goto_pos(s)

      buffer:end_undo_action()
    end,
  },
})

local nav_hydra = hydra.create({
  {
    key = 'n',
    help = 'line number',
    action = function()
      textadept.editing.goto_line()
      buffer:vertical_center_caret()
      buffer:vc_home()
    end,
  },
  {
    key = '1',
    help = '}',
    action = function()
      util.move_to('[}]')
      select_matching()
    end,
    persistent = true,
  },
  {
    key = '2',
    help = ']',
    action = function()
      util.move_to('[\\]]')
      select_matching()
    end,
    persistent = true,
  },
  {
    key = '3',
    help = ')',
    action = function()
      util.move_to('[)]', false)
      select_matching()
    end,
    persistent = true,
  },
  {
    key = '4',
    help = '>',
    action = function()
      util.move_to('[>]')
      select_matching()
    end,
    persistent = true,
  },
  {
    key = 's',
    help = "'",
    action = function()
      util.move_to("[']")
      textadept.editing.select_enclosed("'", "'")
    end,
    persistent = true,
  },
  {
    key = 'd',
    help = '"',
    action = function()
      util.move_to('["]')
      textadept.editing.select_enclosed('"', '"')
    end,
    persistent = true,
  },
  {
    key = 'alt+1',
    help = '{',
    action = function()
      util.move_to('[{]', true)
      select_matching()
    end,
    persistent = true,
  },
  {
    key = 'alt+2',
    help = '[',
    action = function()
      util.move_to('[\\[]', true)
      select_matching()
    end,
    persistent = true,
  },
  {
    key = 'alt+3',
    help = '(',
    action = function()
      util.move_to('[(]', true)
      select_matching()
    end,
    persistent = true,
  },
  {
    key = 'alt+4',
    help = '<',
    action = function()
      util.move_to('[<]', true)
      select_matching()
    end,
    persistent = true,
  },
  {
    key = 'alt+s',
    help = "prev '",
    action = function()
      util.move_to("[']", true)
      textadept.editing.select_enclosed("'", "'")
    end,
    persistent = true,
  },
  {
    key = 'alt+d',
    help = 'prev "',
    action = function()
      util.move_to('["]', true)
      textadept.editing.select_enclosed('"', '"')
    end,
    persistent = true,
  },
  {
    key = 'm',
    help = 'matching',
    action = function()
      local pos = buffer:brace_match(buffer.current_pos, 0)
      buffer:goto_pos(pos)
    end,
    persistent = true,
  },
  {
    key = 'e',
    help = 'buffer end',
    action = buffer.document_end,
  },
  {
    key = 'h',
    help = 'buffer start',
    action = buffer.document_start,
  },
})

local encoding_hydra = hydra.create({
  {
    key = '8',
    help = 'utf-8 encoding',
    action = function()
      set_encoding('utf-8')
    end,
  },
  {
    key = 'a',
    help = 'ascii encoding',
    action = function()
      set_encoding('ascii')
    end,
  },
  {
    key = '6',
    help = 'utf-16 encoding',
    action = function()
      set_encoding('utf-16le')
    end,
  },
  {
    key = 'x',
    help = 'custom encoding',
    action = function()
      local value, button = ui.dialogs.input({
        title = 'Set encoding',
        text = '',
        button1 = 'OK',
        button2 = 'Cancel',
        return_button = true,
      })
      if button == 1 then
        buffer:set_encoding(value)
      end
    end,
  },
})

local eol_hydra = hydra.create({
  {
    key = 'v',
    help = 'view',
    action = function()
      buffer.view_eol = not buffer.view_eol
    end,
    persistent = true,
  },
  {
    key = 't',
    help = 'toggle',
    action = function()
      if buffer.eol_mode == buffer.EOL_LF then
        buffer.eol_mode = buffer.EOL_CRLF
      elseif buffer.eol_mode == buffer.EOL_CRLF then
        buffer.eol_mode = buffer.EOL_LF
      end
      events.emit(events.UPDATE_UI, 1) -- for updating statusbar
    end,
    persistent = true,
  },
  {
    key = 'c',
    help = 'convert',
    action = function()
      buffer:convert_eols(buffer.eol_mode)
    end,
    persistent = true,
  },
  {
    key = 'e',
    help = 'edge column toggle',
    action = function()
      if buffer.edge_mode == buffer.EDGE_LINE then
        buffer.edge_mode = buffer.EDGE_NONE
      else
        buffer.edge_mode = buffer.EDGE_LINE
      end
    end,
    persistent = true,
  },
  {
    key = 'l',
    help = 'set edge column limit',
    action = function()
      local value, button = ui.dialogs.input({
        title = 'Change linelimit',
        informative_text = 'Change linelimit',
        text = buffer.edge_column,
        button1 = 'OK',
        button2 = 'Cancel',
        return_button = true,
      })
      if button ~= 1 then
        return
      end
      buffer.edge_column = value
    end,
  },
})

local whitespace_hydra = hydra.create({
  {
    key = 'v',
    help = 'view',
    action = function()
      buffer.view_ws = buffer.view_ws == 0 and buffer.WS_VISIBLEALWAYS or 0
    end,
    persistent = true,
  },
  {
    key = 't',
    help = 'toggle',
    action = function()
      buffer.use_tabs = not buffer.use_tabs
      events.emit(events.UPDATE_UI, 1) -- for updating statusbar
    end,
    persistent = true,
  },
  { key = 'c', help = 'convert', action = textadept.editing.convert_indentation, persistent = true },
  {
    key = 's',
    help = 'strip',
    action = function()
      if textadept.editing.strip_trailing_spaces then
        textadept.editing.strip_trailing_spaces = false
        buffer.view_ws = buffer.WS_VISIBLEALWAYS
        ui.statusbar_text = 'Strip whitespace is OFF'
      else
        textadept.editing.strip_trailing_spaces = true
        buffer.view_ws = buffer.WS_INVISIBLE
        ui.statusbar_text = 'Strip whitespace is ON'
      end
    end,
    persistent = true,
  },
})

local buffer_hydra = hydra.create({
  {
    key = 'r',
    help = 'reload',
    action = buffer.reload,
  },
  {
    key = 's',
    help = 'save as',
    action = dispatch('saveas'),
  },
  {
    key = 'p',
    help = 'word wrap',
    action = function()
      if view.wrap_mode == view.WRAP_NONE then
        view.wrap_mode = view.WRAP_WORD
        ui.statusbar_text = 'Word wrap ON'
      else
        view.wrap_mode = view.WRAP_NONE
        ui.statusbar_text = 'Word wrap OFF'
      end
    end,
    persistent = true,
  },
  {
    key = 'n',
    help = 'name',
    action = function()
      ui.clipboard_text = buffer.filename
      ui.statusbar_text = 'Copied buffer name to clipboard.'
    end,
  },
  { key = 'w', help = 'whitespace', action = whitespace_hydra },
  { key = 'e', help = 'eol', action = eol_hydra },
  { key = 'c', help = 'encoding', action = encoding_hydra },
  { key = 't', help = 'ctags init', action = dispatch('ctags_init') },
  {
    key = 'k',
    help = 'close all',
    action = function()
      local retval = ui.dialogs.message({
        title = 'Close all buffers?',
        text = 'Do you want to close ALL buffers?',
        icon = 'dialog-question',
        button1 = 'No',
        button2 = 'Yes',
      })
      if retval ~= 2 then
        return
      end
      io.close_all_buffers()
    end,
  },
})

local project_hydra = hydra.create({
  {
    key = 'k',
    help = 'close all',
    action = function()
      local path = io.get_project_root(filename, true)
      if not path then
        ui.statusbar_text = 'not a project'
        return
      end

      local retval = ui.dialogs.message({
        title = 'Close all project buffers?',
        text = 'Do you want to close ALL project buffers?',
        icon = 'dialog-question',
        button1 = 'No',
        button2 = 'Yes',
      })
      if retval ~= 2 then
        return
      end

      for _, b in ipairs(_G._BUFFERS) do
        if b.filename then
          if b.filename:match(path) then
            b:close()
          end
        end
      end
    end,
  },
})

local view_hydra = hydra.create({
  {
    key = 'c',
    help = 'center',
    action = buffer.vertical_center_caret,
  },
  {
    key = 'h',
    help = 'split h',
    action = function()
      view:split()
    end,
  },
  {
    key = 'v',
    help = 'split v',
    action = function()
      view:split(true)
    end,
  },
  {
    key = 'u',
    help = 'unsplit',
    action = function()
      view:unsplit()
    end,
  },
  {
    key = 'w',
    help = 'unsplit&close',
    action = function()
      buffer:close()
      view:unsplit()
    end,
  },
  {
    key = 'k',
    help = 'unsplit all',
    action = function()
      while view:unsplit() do
      end
    end,
  },
  { key = '+', help = 'zoom in', action = view.zoom_in, persistent = true },
  { key = '-', help = 'zoom out', action = view.zoom_out, persistent = true },
  {
    key = '0',
    help = 'reset zoom',
    action = function()
      view.zoom = 0
    end,
  },
  {
    key = 'left',
    help = 'shrink',
    action = m('View/Shrink View'),
    persistent = true,
  },
  {
    key = 'right',
    help = 'grow',
    action = m('View/Grow View'),
    persistent = true,
  },
})

local bookmark_hydra = hydra.create({
  { key = 'm', help = 'toggle', action = textadept.bookmarks.toggle, persistent = true },
  { key = 'k', help = 'clear', action = textadept.bookmarks.clear },
  {
    key = 'n',
    help = 'next',
    action = function()
      textadept.bookmarks.goto_mark(true)
      buffer:vertical_center_caret()
      buffer:vc_home()
    end,
    persistent = true,
  },
  {
    key = 'N',
    help = 'prev',
    action = function()
      textadept.bookmarks.goto_mark(false)
      buffer:vertical_center_caret()
      buffer:vc_home()
    end,
    persistent = true,
  },
})

local open_hydra = hydra.create({
  {
    key = 'o',
    help = 'open',
    action = dispatch('open'),
  },
  {
    key = 'q',
    help = 'quick open',
    action = function()
      io.quick_open(buffer.filename:match('^(.+)[/\\]'))
    end,
  },
  {
    key = 'u',
    help = 'user home',
    action = function()
      io.quick_open(_USERHOME)
    end,
  },
  {
    key = 'i',
    help = 'install home',
    action = function()
      io.quick_open(_HOME)
    end,
  },
  {
    key = 'r',
    help = 'recent',
    action = dispatch('recent')
  },
  {
    key = 'p',
    help = 'project',
    action = function()
      io.quick_open(io.get_project_root(buffer.filename, true))
    end,
  },
  {
    key = 'l',
    help = 'lexer',
    action = dispatch('lexer')
  },
  {
    key = 'm',
    help = 'bookmarks',
    action = dispatch('bookmarks')
  },
  {
    key = 'f',
    help = 'filepath',
    action = function()
      local value, button = ui.dialogs.input({
        title = 'Open file',
        informative_text = 'Path to file',
        button1 = 'OK',
        button2 = 'Cancel',
        return_button = true,
      })
      if button == 1 then
        io.open_file(value)
      end
    end,
  },
})

local git_hydra = hydra.create({
  { key = 'b', help = 'blame', action = function() util.gitblame() end },
})

local run_hydra = hydra.create({
  { key = 'r', help = 'run', action = textadept.run.run },
  { key = 'c', help = 'compile', action = textadept.run.compile },
  { key = 'p', help = 'project', action = function()
    local path = io.get_project_root(buffer.filename, true)
    local build
    for filename in lfs.walk(path, '', 1, true) do
      if filename:match('build') then
        build = filename
        goto finish
      end
    end
    ::finish::
    if not build then build = '' end
    textadept.run.run_project(nil, 'ninja -C ' .. build)
    end,
  },
  { key = 'g', help = 'goto error', action = function()
    textadept.run.goto_error(nil, true)
    end,
    persistent = true,
  },
})

local main_hydra = hydra.create({
  { key = 'o', help = 'open', action = open_hydra },
  { key = 'j', help = 'jump to', action = nav_hydra },
  { key = 'd', help = 'edit', action = edit_hydra },
  { key = 's', help = 'select', action = select_hydra },
  { key = 'e', help = 'selection', action = selection_hydra },
  { key = 'i', help = 'insert', action = insert_hydra },
  { key = 'v', help = 'view', action = view_hydra },
  { key = 'p', help = 'project', action = project_hydra },
  { key = 'b', help = 'buffer', action = buffer_hydra },
  { key = 'm', help = 'bookmark', action = bookmark_hydra },
  { key = 'g', help = 'git', action = git_hydra },
  { key = 'r', help = 'run', action = run_hydra },
  { key = 'n', help = 'new buffer', action = buffer.new },
  { key = 'w', help = 'close buffer', action = buffer.close },
  {
    key = 'W',
    help = 'force close',
    action = function()
      buffer:close(true)
    end,
  },
})

-- map f10/triggerkey to capslock
-- linux ~/.Xmodmap:
-- clear Lock
-- keycode 66 = F10
-- windows:
-- Capslock::F10
-- F10::Capslock
hydra.keys = hydra.create({
  { key = 'f10', help = 'Hydra', action = main_hydra },
})
