view:set_theme('everforest', { font = 'JetBrains Mono NL Light', size = 16 })

local exec = require('exec')
local autoformat = require('autoformat')
local git = require('git')
local hydra = require('hydra')
local quicknav = require('quicknav')
local util = require('util')
local origin = require('origin')
local textredux = require('textredux')
local reduxstyle = textredux.core.style
reduxstyle.list_match_highlight.fore = 'f57d26'
reduxstyle.fs_directory.fore = '3a94c5'
textredux.hijack()
local ctags_redux = require('ctags_redux')
local spellcheck = require('spellcheck')
spellcheck.spellcheckable_styles[lexer.FUNCTION] = true

io.detect_indentation = false
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

ui.command_entry.caret_period = 0
ui.command_entry.caret_style = view.CARETSTYLE_BLOCK
ui.command_entry.caret_line_frame = 1
view.caret_period = 0
view.caret_style = view.CARETSTYLE_BLOCK
view.caret_line_frame = 1
-- keep caret 8 lines away from top/bottom
view:set_y_caret_policy(view.CARET_SLOP | view.CARET_STRICT | view.CARET_EVEN, 8)

view.edge_column = 100
view.edge_color = 0xcccccc

view.indentation_guides = buffer.IV_LOOKBOTH
view.whitespace_size = 3

view.annotation_visible = view.ANNOTATION_STANDARD
textadept.editing.strip_trailing_spaces = true
io.ensure_final_newline = true
view.end_at_last_line = false

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
textadept.editing.autocomplete_all_words = true

buffer.virtual_space_options = buffer.VS_RECTANGULARSELECTION

-- paste into every selection when multiple selections are active
buffer.multi_paste = buffer.MULTIPASTE_EACH

lexer.detect_extensions.conf = 'ini'
lexer.detect_extensions.csv = 'ini'
lexer.detect_extensions.gitconfig = 'ini'
lexer.detect_extensions.ep = 'html'

textadept.editing.auto_pairs = nil

textadept.run.compile_commands.cpp = 'g++ -std=c++20 -O2 "%f"'
textadept.run.run_commands.python = 'python3 -u "%f"'

local function set_buffer_options()
  local name = buffer.lexer_language
  if name == 'yaml' or
      name == 'lua' or
      name == 'html' or
      name == 'css' then
    buffer.use_tabs = false
    buffer.tab_width = 2
  end
  textadept.editing.strip_trailing_spaces = name ~= 'markdown'
end

events.connect(events.LEXER_LOADED, function(name)
  set_buffer_options()
  if package.searchpath(name, package.path) then require(name) end
end)
events.connect(events.BUFFER_AFTER_SWITCH, set_buffer_options)
events.connect(events.VIEW_AFTER_SWITCH, set_buffer_options)
events.connect(events.VIEW_NEW, set_buffer_options)

events.connect(events.FILE_CHANGED, function()
  buffer:reload()
  ui.statusbar_text = 'buffer reloaded'
  return true
end, 1)

autoformat.state['cpp'] = true
autoformat.state['python'] = true

io.quick_open_filters = {'!**/*.{pyc,ttf}', '!build/*', '!extern%a*/*', '!assets/*', '!target/*', '!bin/*'}

local function m(labels)
  local menu = textadept.menu.menubar
  for label in labels:gmatch('[^/]+') do menu = menu[_L[label]] end
  return menu[2]
end

-- unbind some defaults
keys['ctrl+alt+\\'] = nil
keys['ctrl+alt+|'] = nil
keys['ctrl+r'] = nil
keys['ctrl+f'] = nil
keys['ctrl+p'] = nil
keys['ctrl+o'] = nil
keys['ctrl+d'] = nil
keys['ctrl+u'] = nil
keys['ctrl+\t'] = nil
keys['shift+ctrl+\t'] = nil

local function dispatch(case)
  local switch = {}

  switch['open'] = textredux.fs.open_file
  switch['switchbuffer'] = textredux.buffer_list.show
  switch['saveas'] = textredux.fs.save_buffer_as
  -- switch['recent'] = textredux.core.filteredlist.wrap(io.open_recent_file)
  switch['lexer'] = textredux.core.filteredlist.wrap(m('Buffer/Select Lexer...'))
  switch['bookmarks'] = textredux.core.filteredlist.wrap(textadept.bookmarks.goto_mark)
  switch['ctags_init'] = ctags_redux.init_ctags
  switch['ctags_local'] = ctags_redux.find_local
  switch['ctags_global'] = ctags_redux.find_global
  switch['ctags_back'] = ctags_redux.go_back
  switch['ctags_functions'] = ctags_redux.function_list
  switch['switchbuffer_project'] = textredux.core.filteredlist.wrap(util.show_project_buffers)

  -- switch['open'] = io.open_file
  -- switch['switchbuffer'] = ui.switch_buffer
  -- switch['saveas'] = buffer.save_as
  switch['recent'] = io.open_recent_file
  -- switch['lexer'] = m('Buffer/Select Lexer...')
  -- switch['bookmarks'] = textadept.bookmarks.goto_mark
  -- switch['ctags_init'] = function()end
  -- switch['ctags_local'] = function()end
  -- switch['ctags_global'] = function()end
  -- switch['ctags_back'] = function()end
  -- switch['ctags_functions'] = function()end
  -- switch['switchbuffer_project'] = util.show_project_buffers

  return switch[case]
end

events.connect(events.CHAR_ADDED, function(code)
  if buffer.current_pos - buffer:word_start_position(buffer.current_pos, true) < 3 then return end
  if textadept.editing.autocomplete('word') then return end
  textadept.editing.autocomplete(buffer:get_lexer(true))
end)

events.connect(events.KEYPRESS, function(code)
  if code:match('alt.*')
      or code:match('up')
      or code:match('down')
      or code:match('[.]')
      then
    buffer:auto_c_cancel()
  end
end, 1)

local function handle_tab(next)
  if buffer:auto_c_active() then
    (next and buffer.line_down or buffer.line_up)()
    return
  end
  return false
end

keys['\t'] = function()
  return handle_tab(true)
end

keys['shift+\t'] = function()
  return handle_tab(false)
end

keys['ctrl+\t'] = function()
  if textadept.snippets.active then
    buffer:auto_c_cancel()
    textadept.snippets.insert()
  end
end

keys['shift+ctrl+\t'] = function()
  if textadept.snippets.active then
    buffer:auto_c_cancel()
    textadept.snippets.previous()
  end
end

keys.f4 = util.toggle_header

-- editing

keys.f9 = function()
  ctags_redux.function_hint()
end

keys['shift+f9'] = function()
  buffer:annotation_clear_all()
end

keys.f8 = buffer.undo
keys.f5 = buffer.redo

keys['ctrl+r'] = textadept.editing.paste_reindent

keys['alt+4'] = function()
  util.enclose_or_add('<', '>')
end
keys['alt+3'] = function()
  util.enclose_or_add('(', ')')
end
keys['alt+2'] = function()
  util.enclose_or_add('[', ']')
end
keys['alt+1'] = function()
  util.enclose_or_add('{', '}')
end
keys['alt+s'] = function()
  util.enclose_or_add("'", "'")
end
keys['alt+d'] = function()
  util.enclose_or_add('"', '"')
end
keys['alt+c'] = function() util.custom_comment(false) end
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
end

keys['alt+\b'] = function()
  buffer:line_up()
  buffer:line_delete()
end

keys['alt+,'] = function()
  buffer:begin_undo_action()
  buffer:line_end_display()
  buffer:add_text(';')
  buffer:end_undo_action()
end

keys['alt+m'] = function()
  buffer:begin_undo_action()
  buffer:line_end_display()
  buffer:add_text(',')
  buffer:end_undo_action()
end

keys['ctrl+\n'] = function()
  buffer:line_end_display()
  buffer:new_line()
end

-- movement

keys.f3 = ui.find.find_next
keys['shift+f3'] = ui.find.find_prev

keys['alt+h'] = function() buffer:char_left() end
keys['alt+j'] = function() buffer:line_down() end
keys['alt+k'] = function() buffer:line_up() end
keys['alt+l'] = function()
  if buffer.char_at[buffer.current_pos] ~= 0xA then
    buffer:char_right()
  end
end

keys.f1 = dispatch('switchbuffer')
keys.f2 = dispatch('switchbuffer_project')

keys.f11 = function()
  util.find_word_under_cursor(false)
end

keys.f12 = function()
  util.find_word_under_cursor(true)
end

keys['alt+left'] = function()
  util.goto_space(true)
end

keys['alt+right'] = function()
  util.goto_space(false)
end

keys['ctrl+alt+right'] = buffer.word_part_right
keys['ctrl+alt+left'] = buffer.word_part_left

keys['alt+shift+\n'] = function()
  buffer:line_down()
  buffer:line_end()
end

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

keys['alt+home'] = buffer.scroll_to_start
keys['alt+end'] = buffer.scroll_to_end

keys['ctrl+pgup'] = function()
  buffer:page_up()
end
keys['ctrl+pgdn'] = function()
  buffer:page_down()
end

keys['pgup'] = function()
  buffer:goto_line(view:doc_line_from_visible(view.first_visible_line))
  view:vertical_center_caret()
end
keys['pgdn'] = function()
  buffer:goto_line(view:doc_line_from_visible(view.first_visible_line) + view.lines_on_screen - 1)
  view:vertical_center_caret()
end

keys['ins'] = function()
  if buffer.line_count < buffer.lines_on_screen then
    buffer:goto_line(math.floor(buffer.line_count / 2))
  else
    buffer:goto_line(math.floor(buffer.first_visible_line + buffer.lines_on_screen / 2))
  end
end

keys.f6 = util.goto_last_buffer

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

local insert_hydra = hydra.create({
  {
    key = 'm', help = 'allman', action = function()
      util.add_braces('allman', '', true)
    end,
  },
  {
    key = 'alt+m', help = 'allman;', action = function()
      util.add_braces('allman', ';', true)
    end,
  },
  {
    key = 'k', help = 'kr', action = function()
      util.add_braces('kr', '', true)
    end,
  },
  {
    key = 'alt+k', help = 'kr;', action = function()
      util.add_braces('kr', ';', true)
    end,
  },
  {
    key = 'n', help = '\\n', action = function()
      util.insert_text_multi('\\n')
    end,
    persistent = true,
  },
  {
    key = 's', help = 'std::', action = function()
      util.insert_text_multi('std::')
    end,
  },
})

local edit_hydra = hydra.create({
  {
    key = 'up', help = 'move up', action = buffer.move_selected_lines_up,
    persistent = true,
  },
  {
    key = 'down', help = 'move down', action = buffer.move_selected_lines_down,
    persistent = true,
  },

  {
    key = 'home', help = 'del start', action = function()
      buffer:vc_home_extend()
      buffer:delete_range(buffer.selection_start, buffer.selection_end - buffer.selection_start)
    end,
  },
  { key = 'end', help = 'del end', action = buffer.del_line_right, },

  {
    key = 'p', help = 'del para', action = function()
      textadept.editing.select_paragraph()
      buffer:delete_back()
    end,
    persistent = true,
  },

  {
    key = 'u', help = 'upper case', action = function()
      if buffer.selection_empty then textadept.editing.select_word() end
      buffer.upper_case()
    end,
  },
  {
    key = 'l', help = 'lower case', action = function()
      if buffer.selection_empty then textadept.editing.select_word() end
      buffer.lower_case()
    end,
  },

  {
    key = 's', help = 'sort', action = function()
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
    key = 'r', help = 'reverse', action = function()
      textadept.editing.select_word()
      local s = buffer:get_sel_text()
      buffer:replace_sel(s:reverse())
    end,
  },

  {
    key = ' ', help = 'enclose spaces', action = function()
      util.enclose_or_add(' ', ' ')
    end,
    persistent = true,
  },

  { key = 'm', help = 'comment all', action = function()
      util.custom_comment(true)
    end,
  },

  {
    key = '*', help = 'enclose /* */', action = function()
      textadept.editing.enclose('/* ', ' */')
    end,
  },

  {
    key = 'c', help = 'crop', action = function()
      if buffer.selection_empty then textadept.editing.select_word() end
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

})

local selection_hydra = hydra.create({
  {
    key = '1', help = '{}', action = function()
      textadept.editing.select_enclosed('{', '}')
    end,
    persistent = true,
  },
  {
    key = '2', help = '[]', action = function()
      textadept.editing.select_enclosed('[', ']')
    end,
    persistent = true,
  },
  {
    key = '3', help = '()', action = function()
      textadept.editing.select_enclosed('(', ')')
    end,
    persistent = true,
  },
  {
    key = '4', help = '<>', action = function()
      textadept.editing.select_enclosed('<', '>')
    end,
    persistent = true,
  },
  {
    key = 's', help = "''", action = function()
      textadept.editing.select_enclosed("'", "'")
    end,
    persistent = true,
  },
  {
    key = 'd', help = '""', action = function()
      textadept.editing.select_enclosed('"', '"')
    end,
    persistent = true,
  },

  {
    key = 'w', help = 'word', action = function()
      textadept.editing.select_word()
      view:scroll_caret()
    end,
    persistent = true,
  },
  {
    key = 'W', help = 'deselect word', action = function()
      buffer:drop_selection_n(buffer.selections)
      view:scroll_caret()
    end,
    persistent = true,
  },
  {
    key = 'a', help = 'all words', action = function()
      textadept.editing.select_word(true)
    end,
  },

  {
    key = '<', help = '><', action = function()
      textadept.editing.select_enclosed('>', '<')
    end,
    persistent = true,
  },

  {
    key = ' ', help = 'spaces', action = function()
      textadept.editing.select_enclosed(' ', ' ')
    end,
  },
  {
    key = 'x', help = 'custom', action = function()
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
    key = 'm', help = 'matching', action = function()
      util.select_matching()
    end,
  },
  { key = 'p', help = 'paragraph', action = textadept.editing.select_paragraph },
  { key = 'right', help = 'sel right', action = buffer.word_right_extend, persistent = true },
  { key = 'left', help = 'sel left', action = buffer.word_left_extend, persistent = true },
  {
    key = 'home', help = 'to start', action = function()
      buffer:vc_home_extend()
    end,
  },
  {
    key = 'end', help = 'to end', action = function()
      buffer:line_end_extend()
    end,
  },
  {
    key = 'up', help = 'rect up', action = buffer.line_up_rect_extend,
    persistent = true,
  },
  {
    key = 'down', help = 'rect down', action = buffer.line_down_rect_extend,
    persistent = true,
  },
  {
    key = 'pgup', help = 'para up',action = buffer.para_up_extend,
    persistent = true,
  },
  {
    key = 'pgdn', help = 'para down', action = buffer.para_down_extend,
    persistent = true,
  },
  { key = 'b', help = 'buffer end', action = buffer.document_end_extend, },
  { key = 'B', help = 'buffer start', action = buffer.document_start_extend, },
  {
    key = 'e',
    help = 'edit',
    action = edit_hydra,
  },
})

local nav_hydra = hydra.create({
  {
    key = 'j', help = 'line number', action = function()
      textadept.editing.goto_line()
      view:vertical_center_caret()
      buffer:vc_home()
    end,
  },

  { key = 't', help = 'find top most', action = function()
      util.goto_definition()
    end,
  },

  {
    key = 'm', help = 'matching', action = function()
      local pos = buffer:brace_match(buffer.current_pos, 0)
      buffer:goto_pos(pos)
    end,
    persistent = true,
  },

  { key = '1', help = '{}', action = function() util.move_to('[{}]') end, persistent = true },
  { key = '2', help = '[]', action = function() util.move_to('[\\[\\]]') end, persistent = true },
  { key = '3', help = '()', action = function() util.move_to('[\\(\\)]') end, persistent = true },
  { key = '4', help = '<>', action = function() util.move_to('[<>]') end, persistent = true },
  { key = 's', help = "'", action = function() util.move_to("[']") end, persistent = true },
  { key = 'd', help = '"', action = function() util.move_to('["]') end, persistent = true },

  { key = 'alt+1', help = '{}', action = function() util.move_to('[{}]', true) end, persistent = true },
  { key = 'alt+2', help = '[]', action = function() util.move_to('[\\[\\]]', true) end, persistent = true },
  { key = 'alt+3', help = '()', action = function() util.move_to('[\\(\\)]', true) end, persistent = true },
  { key = 'alt+4', help = '<>', action = function() util.move_to('[<>]', true) end, persistent = true },
  { key = 'alt+s', help = "'", action = function() util.move_to("[']", true) end, persistent = true },
  { key = 'alt+d', help = '"', action = function() util.move_to('["]', true) end, persistent = true },

  { key = 'o', help = 'back', action = origin.back, persistent = true, },
  { key = 'i', help = 'forward', action = origin.forward, persistent = true, },

  { key = 'n', help = 'next same indent', action = function() util.goto_matching_indent(false) end, persistent = true, },
  { key = 'N', help = 'next same indent up', action = function() util.goto_matching_indent(true) end, persistent = true, },

  { key = 'z', help = 'zero indent', action = function() util.goto_zero_indent(false) end, persistent = true, },
  { key = 'Z', help = 'zero indent up', action = function() util.goto_zero_indent(true) end, persistent = true, },

  { key = 'l', help = '< indent', action = function() util.goto_diff_indent(false, false) end, persistent = true, },
  { key = 'L', help = '< indent up', action = function() util.goto_diff_indent(false, true) end, persistent = true, },

  { key = 'k', help = '> indent', action = function() util.goto_diff_indent(true, false) end, persistent = true, },
  { key = 'K', help = '> indent up', action = function() util.goto_diff_indent(true, true) end, persistent = true, },

  { key = 'c', help = 'ctags: find', action = dispatch('ctags_global'), },
  { key = 'C', help = 'ctags: back', action = dispatch('ctags_back'), persistent = true, },
  { key = 'u', help = 'ctags: functions', action = dispatch('ctags_functions'), },
})

local encoding_hydra = hydra.create({
  { key = '8', help = 'UTF-8 encoding', action = m('Buffer/Encoding/UTF-8 Encoding'), },
  { key = '6', help = 'UTF-16 encoding', action = m('Buffer/Encoding/UTF-16 Encoding') },
  { key = '5', help = 'CP-1252 encoding', action = m('Buffer/Encoding/CP-1252 Encoding') },
  { key = 'a', help = 'ASCII encoding', action = m('Buffer/Encoding/ASCII Encoding') },
})

local eol_hydra = hydra.create({
  {
    key = 'v', help = 'view', action = function()
      buffer.view_eol = not buffer.view_eol
    end,
    persistent = true,
  },
  {
    key = 't', help = 'toggle', action = function()
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
    key = 'c', help = 'convert', action = function()
      buffer:convert_eols(buffer.eol_mode)
    end,
    persistent = true,
  },
  {
    key = 'e', help = 'edge column toggle', action = function()
      if buffer.edge_mode == buffer.EDGE_LINE then
        buffer.edge_mode = buffer.EDGE_NONE
      else
        buffer.edge_mode = buffer.EDGE_LINE
      end
    end,
    persistent = true,
  },
  {
    key = 'l', help = 'set edge column limit', action = function()
      local value, button = ui.dialogs.input({
        title = 'Change linelimit',
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
    key = 'v', help = 'view', action = function()
      buffer.view_ws = buffer.view_ws == 0 and buffer.WS_VISIBLEALWAYS or 0
    end,
    persistent = true,
  },
  {
    key = 't', help = 'toggle', action = function()
      buffer.use_tabs = not buffer.use_tabs
      events.emit(events.UPDATE_UI, 1) -- for updating statusbar
    end,
    persistent = true,
  },
  { key = 'c', help = 'convert', action = textadept.editing.convert_indentation, persistent = true },
  {
    key = 's', help = 'strip', action = function()
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
  { key = 'w', help = 'width', action = function()
      local value, button = ui.dialogs.input({
        title = 'set tab width',
        button1 = 'OK',
        button2 = 'Cancel',
        return_button = true,
      })
      if button == 1 then
        buffer.tab_width = value
        events.emit(events.UPDATE_UI, 1) -- for updating statusbar
      end
    end,
  },
})

local buffer_hydra = hydra.create({
  { key = 'r', help = 'reload', action = buffer.reload, },
  { key = 's', help = 'save as', action = dispatch('saveas'), },
  {
    key = 'v', help = 'word wrap', action = function()
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
    key = 'n', help = 'name', action = function()
      buffer:copy_text(buffer.filename)
      ui.statusbar_text = 'Copied buffer name to clipboard.'
    end,
  },
  { key = 'w', help = 'whitespace', action = whitespace_hydra },
  { key = 'e', help = 'eol', action = eol_hydra },
  { key = 'f', help = 'format', action = function()
      autoformat.format_buffer(buffer.filename)
    end,
  },
  { key = 't', help = 'toggle autoformat', action = function()
      autoformat.toggle_autoformat()
    end,
  },
  { key = 'c', help = 'encoding', action = encoding_hydra },
  {
    key = 'k', help = 'close all', action = function()
      local button = ui.dialogs.message
      {
        title = 'Close all buffers?',
        text = 'Do you want to close ALL buffers?',
        icon = 'dialog-question',
        button1 = 'Yes',
        button2 = 'No',
      }
      if button == 2 then return end
      io.close_all_buffers()
    end,
  },
  {
    key = 'del', help = 'delete file', action = function()
      local button = ui.dialogs.message
      {
        title = 'Delete file?',
        text = buffer.filename,
        icon = 'dialog-question',
        button1 = 'Yes',
        button2 = 'No',
      }
      if button == 2 then return end
      os.remove(buffer.filename)
    end,
  },
})

local project_hydra = hydra.create({
  {
    key = 'k', help = 'close all', action = function()
      local rootpath = util.get_project_root()
      if not rootpath then return end
      rootpath = rootpath:gsub('%-', '%%-')

      local button = ui.dialogs.message
      {
        title = 'Close all project buffers?',
        text = 'Do you want to close ALL project buffers?',
        icon = 'dialog-question',
        button1 = 'Yes',
        button2 = 'No',
      }
      if button == 2 then return end

      for i = #_G._BUFFERS, 1, -1 do
        if _G._BUFFERS[i].filename:match(rootpath) then
          _G._BUFFERS[i]:close()
        end
      end
    end,
  },

  { key = 'c', help = 'ctags: init', action = dispatch('ctags_init') },
})

local git_hydra = hydra.create({
  { key = 'b', help = 'blame', action = function() git.blame() end },
  { key = 'f', help = 'toggle blame follow', action = git.toggle_blame_follow, },
  { key = 'l', help = 'diff of current line', action = git.line_diff, },
  { key = 'r', help = 'show file at revision', action = git.show_rev, },
  { key = 'h', help = 'heat map', action = git.heatmap, },
  { key = 'c', help = 'clear markers', action = git.clear_markers, },
})

local window_hydra = hydra.create({
  { key = 's', help = 'spawn buffer', action = buffer.new },
  { key = 'w', help = 'close buffer', action = buffer.close },
  {
    key = '1', help = 'split |', action = function()
      view:split(true)
    end,
  },
  {
    key = '2', help = 'split -', action = function()
      view:split()
    end,
  },
  {
    key = '3', help = 'unsplit', action = function()
      view:unsplit()
    end,
  },
  {
    key = 'q', help = 'unsplit&close', action = function()
      buffer:close()
      view:unsplit()
    end,
  },
  {
    key = 'x', help = 'force close', action = function()
      buffer:close(true)
    end,
  },
  { key = 'c', help = 'center', action = view.vertical_center_caret, },
  {
    key = 'k', help = 'unsplit all', action = function()
      while view:unsplit() do
      end
    end,
  },
  { key = '+', help = 'zoom in', action = view.zoom_in, persistent = true },
  { key = '-', help = 'zoom out', action = view.zoom_out, persistent = true },
  {
    key = '0', help = 'reset zoom', action = function()
      view.zoom = 0
    end,
  },
  {
    key = 'left', help = 'shrink',
    action = m('View/Shrink View'),
    persistent = true,
  },
  {
    key = 'right', help = 'grow',
    action = m('View/Grow View'),
    persistent = true,
  },
})

local bookmark_hydra = hydra.create({
  { key = 'm', help = 'toggle', action = textadept.bookmarks.toggle, persistent = true },
  { key = 'c', help = 'clear', action = textadept.bookmarks.clear },
  {
    key = 'n', help = 'next', action = function()
      textadept.bookmarks.goto_mark(true)
      view:vertical_center_caret()
      buffer:vc_home()
    end,
    persistent = true,
  },
  {
    key = 'N', help = 'prev', action = function()
      textadept.bookmarks.goto_mark(false)
      view:vertical_center_caret()
      buffer:vc_home()
    end,
    persistent = true,
  },
})

local quicknav_hydra = hydra.create({
  { key = '1', help = 'quicknav 1', action = function() quicknav.go(1) end, },
  { key = '2', help = 'quicknav 2', action = function() quicknav.go(2) end, },
  { key = '3', help = 'quicknav 3', action = function() quicknav.go(3) end, },
  { key = '4', help = 'quicknav 4', action = function() quicknav.go(4) end, },
  { key = 'alt+1', help = 'set quicknav 1', action = function() quicknav.set(1) end, },
  { key = 'alt+2', help = 'set quicknav 2', action = function() quicknav.set(2) end, },
  { key = 'alt+3', help = 'set quicknav 3', action = function() quicknav.set(3) end, },
  { key = 'alt+4', help = 'set quicknav 4', action = function() quicknav.set(4) end, },
})

local open_hydra = hydra.create({
  { key = 'o', help = 'open', action = dispatch('open'), },
  {
    key = 'f', help = 'flat open', action = function()
      io.quick_open(buffer.filename:match('^(.+)[/\\]'))
    end,
  },
  {
    key = 'u', help = 'user home', action = function()
      io.quick_open(_USERHOME)
    end,
  },
  {
    key = 'i', help = 'install home', action = function()
      io.quick_open(_HOME)
    end,
  },
  { key = 'r', help = 'recent', action = dispatch('recent') },
  {
    key = 'p', help = 'project', action = function()
      io.quick_open(nil)
    end,
  },
  { key = 'l', help = 'lexer', action = dispatch('lexer') },
  { key = 'm', help = 'bookmarks', action = dispatch('bookmarks') },
  {
    key = 'e', help = 'enter filepath', action = function()
      local value, button = ui.dialogs.input({
        title = 'Enter filepath',
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

local find_hydra = hydra.create({
  {key = 'f', help = 'find', action = function()
      ui.find.focus({ in_files = false, incremental = true, regex = false, match_case = false, whole_word = false})
    end
  },
  {key = 'd', help = 'find on disk', action = function()
      ui.find.focus({ in_files = true, incremental = false, regex = false, match_case = false, whole_word = false})
    end
  },
  {key = 'r', help = 'find regex', action = function()
      ui.find.focus({ in_files = false, incremental = true, regex = true, match_case = false, whole_word = false})
    end
  },
  {key = 'c', help = 'find case sensitive', action = function()
      ui.find.focus({ in_files = false, incremental = true, regex = false, match_case = true, whole_word = false})
    end
  },
  {key = 'w', help = 'find word', action = function()
      ui.find.focus({ in_files = false, incremental = true, regex = false, match_case = false, whole_word = true})
    end
  },
})

local run_hydra = hydra.create({
  { key = 'l', help = 'lint', action = function()
      exec.run('lint')
    end
  },
  { key = 'i', help = 'inline build', action = function()
      exec.run('build')
    end
  },
  { key = 'r', help = 'run', action = textadept.run.run },
  { key = 'c', help = 'compile', action = textadept.run.compile },
  {
    key = 'b', help = 'build', action = function()
      local rootpath = util.get_project_root()
      if not rootpath then return end
      textadept.run.build_commands[rootpath] = 'ninja -C ' .. rootpath .. '/build'
      textadept.run.build(rootpath)
    end,
  },
  { key = 'p', help = 'project', action = function()
    textadept.run.run_project(nil, '')
  end, },
  { key = 'n', help = 'next', action = function()
      exec.next_error(true)
    end,
    persistent = true,
  },
  { key = 'N', help = 'prev', action = function()
      exec.next_error(false)
    end,
    persistent = true,
  },
})

local main_hydra = hydra.create({
  { key = 'o', help = 'open', action = open_hydra },
  { key = 'j', help = 'jump to', action = nav_hydra },
  { key = 'e', help = 'edit', action = edit_hydra },
  { key = 's', help = 'select', action = selection_hydra },
  { key = 'i', help = 'insert', action = insert_hydra },
  { key = 'n', help = 'snippets', action = textadept.snippets.select },
  { key = 'w', help = 'window', action = window_hydra },
  { key = 'p', help = 'project', action = project_hydra },
  { key = 'g', help = 'git', action = git_hydra },
  { key = 'b', help = 'buffer', action = buffer_hydra },
  { key = 'f', help = 'find', action = find_hydra },
  { key = 'm', help = 'bookmark', action = bookmark_hydra },
  { key = 'q', help = 'quick access', action = quicknav_hydra },
  { key = 'r', help = 'run', action = run_hydra },
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

snippets.cpp.arr = 'std::array<${1:bool}, ${2:8}> $0'
snippets.cpp.cdur = 'std::chrono::duration<$1>($0)'
snippets.cpp.csec = 'std::chrono::seconds($0)'
snippets.cpp.cls = '#pragma once\n\nclass $1 final\n{\npublic:\n\t$1();\n\t~$1();\n\nprivate:\n\t$0\n};'
snippets.cpp.dcst = 'dynamic_cast<$1>($0)'
snippets.cpp.enmcls = 'enum class $1 ${2:: std::uint8_t} {\n\t$0\n};'
snippets.cpp.fl = 'for (${1:auto}${2: const&} $3 : $4) {\n\t$0\n}'
snippets.cpp.fli = 'for ($1; $2; $3) {\n\t$0\n}'
snippets.cpp.fmt = 'std::format("{}$1", $0)'
snippets.cpp.lmda = '[${1:&}]($2){\n\t$3\n}'
snippets.cpp.main = 'int main(int argc, char** argv) {\n\t$0\n\treturn 0;\n}'
snippets.cpp.map = 'std::map<$1, $2>'
snippets.cpp.mks = 'std::make_shared<$1>($0)'
snippets.cpp.mku = 'std::make_unique<$1>($0)'
snippets.cpp.ns = 'namespace $1 {\n\t$0\n} // namespace $1'
snippets.cpp.prnt = [[std::cout << $0 << "\\n";]]
snippets.cpp.rcst = 'reinterpret_cast<$1>($0)'
snippets.cpp.scst = 'static_cast<${1:std::size_t}>($0)'
snippets.cpp.sizet = 'std::size_t'
snippets.cpp.slp = 'std::this_thread::sleep_for(std::chrono::${1:seconds}($0));'
snippets.cpp.sptr = 'std::shared_ptr<$1>'
snippets.cpp.str = 'std::string'
snippets.cpp.stt = 'struct $1\n{\n\t$0\n};'
snippets.cpp.swt = 'switch ($1) {\ncase $2:\n\t$0\nbreak;\n\ndefault:\nbreak;\n}'
snippets.cpp.tmpl = 'template <typename ${0:T}>'
snippets.cpp.uptr = 'std::unique_ptr<$1>'
snippets.cpp.use = '#include <$0>'
snippets.cpp.usel = '#include "$0"'
snippets.cpp.vec = 'std::vector<$1>'
snippets.cpp.vecn = 'std::vector<$1> $2(${3:n}, ${0:val});'

snippets.rust.fl = 'for $1 in $2 {\n\t$0\n}'
snippets.rust.fli = 'for $1 in $2..$3 {\n\t$0\n}'
snippets.rust.fn = 'fn $1($2) -> ${3:()} {\n\t$0\n}'
snippets.rust.lmda = '|$1| { $2 }'
snippets.rust.prnt = 'println!("{}$1", $0);'
snippets.rust.swt = 'match $1 {\n\t$0\n\t_ => (),\n}'
snippets.rust.vec = 'let ${1:mut }$2 = vec![$0];'
snippets.rust.vecn = 'let ${1:mut }$0 = Vec::new();'

snippets.perl.dra = '->@*'
snippets.perl.drh = '->%*'
snippets.perl.drn = '->$#*'
snippets.perl.ds = '__DATA__\n'
snippets.perl.fl = 'for my $$1 (@$2) {\n\t$0\n}'
snippets.perl.flh = 'for my $$1 (sort keys %$2) {\n\t$0\n}'
snippets.perl.flha = 'for my $$1 ($$2{$$3}->@*){\n\t$0\n}'
snippets.perl.fli = 'for (my $$1; $$2; $3) {\n\t$0\n}'
snippets.perl.fn = 'sub $1 {\n\t$0\n}'
snippets.perl.jn = 'join("$1", @$0)'
snippets.perl.pa = 'push(@$1, $$0);'
snippets.perl.pha = 'push($$1{$$2}->@*, $$0);'
snippets.perl.prnt = 'print "$$0";'
snippets.perl.rem = 'm/$2/$0'
snippets.perl.res = '${1:|s,y|}/$2/$3/$0;'
snippets.perl.sp = 'split(/$1/, $$0)'
snippets.perl.usc = 'use strict;\nuse warnings;\n\n'
snippets.perl.wd = 'while (<${1:DATA}>) {\n\tchomp;\n\t$0\n}'

snippets.python.fl = 'for $1 in $2:\n\t$0\n'
snippets.python.fn = 'def $1($2):\n\t$0'
snippets.python.lg = 'logging.${1:info}("$2", $0)'
snippets.python.prnt = 'print(f"$0")'
snippets.python['if'] = 'if $1:\n\t$0'

snippets.lua.cat = 'table.concat($0)'
snippets.lua.fl = 'for $1 in pairs($2) do\n\t$0\nend'
snippets.lua.fli = 'for $1 in ipairs($2) do\n\t$0\nend'
snippets.lua.fn = '${1:local }function${2:()}\n\t$0\nend'
snippets.lua.ins = 'table.insert($0)'
snippets.lua['if'] = 'if $1 then\n\t$0\nend'
