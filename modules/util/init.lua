local M = {}

local last_buffer = _BUFFERS[#_BUFFERS]

function M.get_project_root()
  local rootpath = io.get_project_root(true)
  if not rootpath then
    ui.statusbar_text = 'Not a project'
    return nil
  end
  return rootpath
end

function M.find_word_under_cursor(next)
  if buffer.selection_empty then textadept.editing.select_word() end
  local target = buffer:get_sel_text()
  ui.find.whole_word = true
  ui.find.match_case = true
  ui.find.incremental = false
  ui.find.regex = false
  ui.find.in_files = false
  events.emit(events.FIND, target, next)
end

function M.select_until(target, reverse)
  local cur_line_nr = buffer:line_from_position(buffer.current_pos)
  if reverse then
    buffer.target_start = buffer.selection_empty and buffer.current_pos - 1 or buffer.selection_start - 1
    buffer.target_end = buffer:position_from_line(cur_line_nr)
  else
    buffer.target_start = buffer.selection_empty and buffer.current_pos + 1 or buffer.selection_end + 1
    buffer.target_end = buffer.line_end_position[cur_line_nr]
  end

  buffer.search_flags = buffer.FIND_REGEXP
  local pos = buffer:search_in_target(target)
  if pos ~= -1 then buffer:set_selection(buffer.current_pos, reverse and pos + 1 or pos) end
end

function M.goto_space(reverse)
  local cur_line_nr = buffer:line_from_position(buffer.current_pos)
  if reverse then
    buffer.target_start = buffer.current_pos - 1
    buffer.target_end = buffer:position_from_line(cur_line_nr)
  else
    buffer.target_start = buffer.current_pos
    buffer.target_end = buffer.line_end_position[cur_line_nr]
  end

  buffer.search_flags = buffer.FIND_REGEXP
  if buffer:search_in_target('[\\s\\S]\\s{1,1}\\S') ~= -1 then
    buffer:goto_pos(buffer.target_start + 2)
    buffer:choose_caret_x()
  end
end

function M.move_to(target, reverse)
  if reverse then
    buffer.target_start = buffer.current_pos - 1
    buffer.target_end = 0
  else
    buffer.target_start = buffer.current_pos + 1
    buffer.target_end = buffer.length
  end

  buffer.search_flags = buffer.FIND_REGEXP
  if buffer:search_in_target(target) ~= -1 then buffer:goto_pos(buffer.target_start) end
end

-- lastbuffer
events.connect(events.BUFFER_BEFORE_SWITCH, function()
  last_buffer = view.buffer
end)

-- Switch to last buffer.
function M.goto_last_buffer()
  view:goto_buffer(last_buffer)
end

function M.add_braces(style, append, tab)
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
  if tab then buffer:tab() end
  buffer:end_undo_action()
end

function M.enclose_or_add(left, right)
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

function M.insert_text_multi(text)
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

function M.select_matching()
  local target = buffer:brace_match(buffer.current_pos, 0)
  if target < buffer.current_pos then
    buffer:set_selection(buffer.current_pos, target + 1)
  else
    buffer:set_selection(buffer.current_pos + 1, target)
  end
end

function M.custom_comment(force)
  local lang = buffer:get_lexer(true)
  local comment = textadept.editing.comment_string[lang] or buffer.property['scintillua.comment.' .. lang]
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

  buffer:begin_undo_action()
  for line = s, not ignore_last_line and e or e - 1 do
    local full_line = buffer:get_line(line)
    if full_line:match('^%s*$') then goto continue end

    local p = buffer.line_indent_position[line]

    local uncomment = full_line:match('^%s*(' .. prefix_esc .. '%s?)')
    if uncomment then uncomment = uncomment:gsub('\n*$', '') end

    if not uncomment or force then
      buffer:insert_text(p, prefix)
      if suffix ~= '' then buffer:insert_text(buffer.line_end_position[line], suffix) end
    end

    if uncomment then
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
  local start_pos = buffer:position_from_line(s)
  anchor, pos = math.max(anchor, start_pos), math.max(pos, start_pos)
  if s ~= e then
    buffer:set_sel(anchor, pos)
  else
    buffer:goto_pos(pos)
  end
end

local function find_indent(target, prev, operation)
  local origin = buffer:line_from_position(buffer.current_pos)
  local line = origin
  local function search()
    while true do
      line = prev and line - 1 or line + 1
      if line < 1 or line > buffer.line_count then return origin end

      local indentation = buffer.line_indentation[line]
      if
        buffer:get_line(line):match('[^%s]+')
        and (
          (operation == 'eq' and indentation == target)
          or (operation == 'gt' and indentation > target)
          or (operation == 'lt' and indentation < target)
        )
      then
        return line
      end
    end
  end
  buffer:goto_line(search())
  view:vertical_center_caret()
  buffer:vc_home()
end

function M.goto_diff_indent(gt, prev)
  local line = buffer:line_from_position(buffer.current_pos)
  local indent = buffer.line_indentation[line]
  if gt then
    find_indent(indent, prev, 'gt')
  else
    find_indent(indent, prev, 'lt')
  end
end

function M.goto_matching_indent(prev)
  local line = buffer:line_from_position(buffer.current_pos)
  find_indent(buffer.line_indentation[line], prev, 'eq')
end

function M.goto_zero_indent(prev)
  find_indent(0, prev, 'eq')
end

function M.goto_definition()
  if buffer.selection_empty then textadept.editing.select_word() end
  ui.find.find_entry_text = buffer:get_sel_text()
  ui.find.whole_word = true
  ui.find.match_case = true
  ui.find.incremental = false
  ui.find.regex = false
  ui.find.in_files = false
  buffer:document_start()
  buffer:search_anchor()
  ui.find.find_next()
end

function M.show_project_buffers()
  local rootpath = io.get_project_root(true)
  if not rootpath then
    ui.statusbar_text = 'not a project'
    return
  end
  rootpath = rootpath:gsub('%-', '%%-')

  local buffers = {}
  for i = #_G._BUFFERS, 1, -1 do
    if _G._BUFFERS[i].filename then
      if _G._BUFFERS[i].filename:match(rootpath .. '[/\\]') then
        local buffer_name = _G._BUFFERS[i].filename:match('[^/\\]+$')
        buffers[#buffers + 1] = (_G._BUFFERS[i].modify and '*' or '') .. buffer_name
        buffers[#buffers + 1] = _G._BUFFERS[i].filename
      end
    end
  end

  local index = ui.dialogs.list({ title = 'Project Buffers', columns = { 'Name', 'Path' }, items = buffers })
  if not index then return end
  io.open_file(buffers[index * 2])
end

function M.goto_fold_point(next)
  local first = buffer:line_from_position(buffer.current_pos)
  first = next and first + 1 or first - 1
  local last = next and buffer.line_count or 1
  local step = next and 1 or -1

  local pos = 0

  for i = first, last, step do
    if (buffer.fold_level[i] & buffer.FOLDLEVELHEADERFLAG) > 0 and view.line_visible[i] then
      pos = i
      break
    end
  end

  if pos > 0 then
    buffer.goto_line(pos)
    view:vertical_center_caret()
  end
end

return M
