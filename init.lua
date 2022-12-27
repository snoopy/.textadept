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
view.whitespace_size = 3

textadept.editing.strip_trailing_spaces = true
io.ensure_final_newline = true
view.end_at_last_line = false

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

local function m(labels)
  local menu = textadept.menu.menubar
  for label in labels:gmatch('[^/]+') do menu = menu[_L[label]] end
  return menu[2]
end

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
local qapp = require('qapp')

local function dispatch(case)
  local switch = {}

  switch['open'] = textredux.fs.open_file
  switch['switchbuffer'] = textredux.buffer_list.show
  switch['saveas'] = textredux.fs.save_buffer_as
  switch['recent'] = textredux.core.filteredlist.wrap(io.open_recent_file)
  switch['lexer'] = textredux.core.filteredlist.wrap(m('Buffer/Select Lexer...'))
  switch['bookmarks'] = textredux.core.filteredlist.wrap(textadept.bookmarks.goto_mark)
  switch['ctags_init'] = ctags_redux.init_ctags
  switch['ctags_local'] = ctags_redux.find_local
  switch['ctags_global'] = ctags_redux.find_global
  switch['ctags_back'] = ctags_redux.go_back

  -- switch['open'] = io.open_file
  -- switch['switchbuffer'] = ui.switch_buffer
  -- switch['saveas'] = buffer.save_as
  -- switch['recent'] = io.open_recent_file
  -- switch['lexer'] = m('Buffer/Select Lexer...')
  -- switch['bookmarks'] = textadept.bookmarks.goto_mark
  -- switch['ctags_init'] = function()end
  -- switch['ctags_local'] = function()end
  -- switch['ctags_global'] = function()end
  -- switch['ctags_back'] = function()end

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

keys.f4 = util.toggle_header

-- editing

keys.f8 = buffer.undo
keys.f5 = buffer.redo

keys['ctrl+r'] = textadept.editing.paste_reindent

keys.f2 = function()
  util.clear_indicators()
  textadept.editing.select_word()
  view:scroll_caret()
end

keys['shift+f2'] = function()
  buffer:drop_selection_n(buffer.selections)
  view:scroll_caret()
end

keys['alt+f2'] = function()
  util.clear_indicators()
  textadept.editing.select_word(true)
end

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
keys['alt+c'] = util.custom_comment
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

keys['alt+h'] = function() buffer:char_left() end
keys['alt+j'] = function() buffer:line_down() end
keys['alt+k'] = function() buffer:line_up() end
keys['alt+l'] = function()
  if buffer.char_at[buffer.current_pos] ~= 0xA then
    buffer:char_right()
  end
end

keys.f1 = dispatch('switchbuffer')

keys.f3 = function()
  util.clear_indicators()
  ui.find.focus({ in_files = false, incremental = true, regex = false, match_case = false})
end

keys['shift+f3'] = function()
  util.clear_indicators()
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

keys['ctrl+pgup'] = function()
  buffer:page_up()
end
keys['ctrl+pgdn'] = function()
  buffer:page_down()
end

keys['pgup'] = function()
  buffer.stuttered_page_up()
  buffer:vertical_center_caret()
end
keys['pgdn'] = function()
  buffer.stuttered_page_down()
  buffer:vertical_center_caret()
end

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
    key = 'n', help = '\\n', action = function()
      util.insert_text_multi('\\n')
    end,
    persistent = true,
  },
  {
    key = 'm', help = 'allman', action = function()
      add_braces('allman', '', true)
    end,
  },
  {
    key = 'alt+m', help = 'allman;', action = function()
      add_braces('allman', ';', true)
    end,
  },
  {
    key = 'k', help = 'kr', action = function()
      add_braces('kr', '', true)
    end,
  },
  {
    key = 'alt+k', help = 'kr;', action = function()
      add_braces('kr', ';', true)
    end,
  },
  {
    key = 's', help = 'std::', action = function()
      util.insert_text_multi('std::')
    end,
  },
  {
    key = 'i', help = 'include', action = function()
      util.insert_text_multi('#include <>')
      buffer:char_left()
    end,
  },
  {
    key = 'l', help = 'include local', action = function()
      util.insert_text_multi('#include ""')
      buffer:char_left()
    end,
  },
  { key = 'p', help = 'namespace', action = util.insert_namespace },
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

  {
    key = 'c', help = 'enclose /* */', action = function()
      textadept.editing.enclose('/* ', ' */')
    end,
  },
})

local selection_hydra = hydra.create({
  {
    key = '1', help = '{}', action = function()
      if buffer.selection_empty then
        textadept.editing.select_enclosed('{', '}')
      else
        util.move_to('[}]')
        util.select_matching()
      end
    end,
    persistent = true,
  },
  {
    key = '2', help = '[]', action = function()
      if buffer.selection_empty then
        textadept.editing.select_enclosed('[', ']')
      else
        util.move_to('[\\]]')
        util.select_matching()
      end
    end,
    persistent = true,
  },
  {
    key = '3', help = '()', action = function()
      if buffer.selection_empty then
        textadept.editing.select_enclosed('(', ')')
      else
        util.move_to('[)]')
        util.select_matching()
      end
    end,
    persistent = true,
  },
  {
    key = '4', help = '<>', action = function()
      if buffer.selection_empty then
        textadept.editing.select_enclosed('<', '>')
      else
        util.move_to('[>]')
        util.select_matching()
      end
    end,
    persistent = true,
  },
  {
    key = 's', help = "''", action = function()
      if not buffer.selection_empty then
        util.move_to("[']")
      end
      textadept.editing.select_enclosed("'", "'")
    end,
    persistent = true,
  },
  {
    key = 'd', help = '""', action = function()
      if not buffer.selection_empty then
        util.move_to('["]')
      end
      textadept.editing.select_enclosed('"', '"')
    end,
    persistent = true,
  },

  {
    key = 'alt+1', help = '{', action = function()
      util.move_to('[{]', true)
      util.select_matching()
    end,
    persistent = true,
    },
    {
      key = 'alt+2', help = '[', action = function()
        util.move_to('[\\[]', true)
        util.select_matching()
      end,
      persistent = true,
    },
    {
      key = 'alt+3', help = '(', action = function()
        util.move_to('[(]', true)
        util.select_matching()
      end,
      persistent = true,
    },
    {
      key = 'alt+4', help = '<', action = function()
        util.move_to('[<]', true)
        util.select_matching()
      end,
      persistent = true,
    },
    {
      key = 'alt+s', help = "rev '", action = function()
        util.move_to("[']", true)
        textadept.editing.select_enclosed("'", "'")
      end,
      persistent = true,
    },
    {
      key = 'alt+d', help = 'rev "', action = function()
        util.move_to('["]', true)
        textadept.editing.select_enclosed('"', '"')
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
      buffer:copy()
    end,
  },
  {
    key = 'end', help = 'to end', action = function()
      buffer:line_end_extend()
      buffer:copy()
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
  { key = 'h', help = 'buffer start', action = buffer.document_start_extend, },
  { key = 'e', help = 'buffer end', action = buffer.document_end_extend, },

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

local nav_hydra = hydra.create({
  {
    key = 'n', help = 'line number', action = function()
      textadept.editing.goto_line()
      buffer:vertical_center_caret()
      buffer:vc_home()
    end,
  },

  { key = '1', help = 'qapp 1', action = function() qapp.go(1) end, },
  { key = '2', help = 'qapp 2', action = function() qapp.go(2) end, },
  { key = '3', help = 'qapp 3', action = function() qapp.go(3) end, },
  { key = '4', help = 'qapp 4', action = function() qapp.go(4) end, },
  { key = 'alt+1', help = 'set qapp 1', action = function() qapp.set(1) end, },
  { key = 'alt+2', help = 'set qapp 2', action = function() qapp.set(2) end, },
  { key = 'alt+3', help = 'set qapp 3', action = function() qapp.set(3) end, },
  { key = 'alt+4', help = 'set qapp 4', action = function() qapp.set(4) end, },

  {
    key = 'm', help = 'matching', action = function()
      local pos = buffer:brace_match(buffer.current_pos, 0)
      buffer:goto_pos(pos)
    end,
    persistent = true,
  },
  { key = 'e', help = 'buffer end', action = buffer.document_end, },
  { key = 'h', help = 'buffer start', action = buffer.document_start, },
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
})

local buffer_hydra = hydra.create({
  { key = 'r', help = 'reload', action = buffer.reload, },
  { key = 's', help = 'save as', action = dispatch('saveas'), },
  {
    key = 'p', help = 'word wrap', action = function()
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
      ui.clipboard_text = buffer.filename
      ui.statusbar_text = 'Copied buffer name to clipboard.'
    end,
  },
  { key = 'w', help = 'whitespace', action = whitespace_hydra },
  { key = 'e', help = 'eol', action = eol_hydra },
  { key = 'c', help = 'encoding', action = encoding_hydra },
  {
    key = 'k', help = 'close all', action = function()
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
    key = 'k', help = 'close all', action = function()
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

  { key = 'b', help = 'blame', action = function() util.gitblame() end },

  { key = 'f1', help = 'ctags: find local', action = dispatch('ctags_local'), },
  { key = 'f2', help = 'ctags: find global', action = dispatch('ctags_global'), },
  { key = 'f8', help = 'ctags: back', action = dispatch('ctags_back'), },
  { key = 'c', help = 'ctags: init', action = dispatch('ctags_init') },
})

local view_hydra = hydra.create({
  { key = 'c', help = 'center', action = buffer.vertical_center_caret, },
  {
    key = 'h', help = 'split h', action = function()
      view:split()
    end,
  },
  {
    key = 'v', help = 'split v', action = function()
      view:split(true)
    end,
  },
  {
    key = 'u', help = 'unsplit', action = function()
      view:unsplit()
    end,
  },
  {
    key = 'w', help = 'unsplit&close', action = function()
      buffer:close()
      view:unsplit()
    end,
  },
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
  { key = 'k', help = 'clear', action = textadept.bookmarks.clear },
  {
    key = 'n', help = 'next', action = function()
      textadept.bookmarks.goto_mark(true)
      buffer:vertical_center_caret()
      buffer:vc_home()
    end,
    persistent = true,
  },
  {
    key = 'p', help = 'prev', action = function()
      textadept.bookmarks.goto_mark(false)
      buffer:vertical_center_caret()
      buffer:vc_home()
    end,
    persistent = true,
  },
})

local open_hydra = hydra.create({
  { key = 'o', help = 'open', action = dispatch('open'), },
  {
    key = 'q', help = 'quick open', action = function()
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
      io.quick_open(io.get_project_root(buffer.filename, true))
    end,
  },
  { key = 'l', help = 'lexer', action = dispatch('lexer') },
  { key = 'm', help = 'bookmarks', action = dispatch('bookmarks') },
  {
    key = 'f', help = 'filepath', action = function()
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

local run_hydra = hydra.create({
  { key = 'r', help = 'run', action = textadept.run.run },
  { key = 'c', help = 'compile', action = textadept.run.compile },
  {
    key = 'b', help = 'build', action = function()
      local root = io.get_project_root(buffer.filename, true)
      local build_path = buffer.filename:match('(' .. root .. '[/\\][^/\\]+)')
      if not build_path then build_path = root end
      textadept.run.build_commands[root] = 'ninja -C ' .. build_path .. '/build'
      textadept.run.build(root)
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
  { key = 'e', help = 'edit', action = edit_hydra },
  { key = 's', help = 'select', action = selection_hydra },
  { key = 'i', help = 'insert', action = insert_hydra },
  { key = 'v', help = 'view', action = view_hydra },
  { key = 'p', help = 'project', action = project_hydra },
  { key = 'b', help = 'buffer', action = buffer_hydra },
  { key = 'm', help = 'bookmark', action = bookmark_hydra },
  { key = 'r', help = 'run', action = run_hydra },
  { key = 'n', help = 'new buffer', action = buffer.new },
  { key = 'w', help = 'close buffer', action = buffer.close },
  {
    key = 'W', help = 'force close', action = function()
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
