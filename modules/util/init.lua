local M = {}

M.auto_format = {}

events.connect(events.FILE_AFTER_SAVE, function(filename)
  if M.auto_format[buffer.lexer_language] then
    M.format_buffer()
  end
end)

function M.gitblame()
  local rootpath = io.get_project_root(true)
  if not rootpath then
    ui.statusbar_text = 'Not a git directory'
    return
  end
  local filepath = buffer.filename
  local linenumber = buffer:line_from_position(buffer.current_pos)

  local file = assert(io.popen('git -C ' .. rootpath .. ' blame ' .. filepath, 'r'))
  local result = assert(file:read('*a'))
  file:close()

  ui.print(result)
  buffer.goto_line(linenumber)
end

function M.gitshowrev()
  local project = io.get_project_root(true)
  local file = buffer.filename
  if not project then return end
  project = project:gsub('%-', '%%-')
  file = file:gsub(project, '')
  file = file:gsub('^[/\\]', '')
  file = file:gsub('[\\]', '/')

  local revision, button = ui.dialogs.input({
    title = 'Enter git revision',
    return_button = true,
  })
  if button ~= 1 then return end

  textadept.run.run_project(nil, 'git show ' .. revision .. ':' .. file)
end

function M.find_word_under_cursor(prev)
  if buffer.selection_empty then
    textadept.editing.select_word()
  end
  ui.find.find_entry_text = buffer:get_sel_text()
  ui.find.whole_word = true
  ui.find.match_case = true
  ui.find.incremental = false
  ui.find.regex = false
  ui.find.find_in_files = false
  buffer:search_anchor()
  if prev then
    ui.find.find_prev()
  else
    ui.find.find_next()
  end
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
  if buffer:search_in_target("[\\s\\S]\\s{1,1}\\S") ~= -1 then
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
  if buffer:search_in_target(target) ~= -1 then
    buffer:goto_pos(buffer.target_start)
    buffer:choose_caret_x()
  end
end

-- lastbuffer

-- Save the buffer index before switching.
events.connect(events.BUFFER_BEFORE_SWITCH, function()
    for _, b in ipairs(_BUFFERS) do
      if b == buffer then
        last_buffer = b
        break
      end
    end
  end)

-- Switch to last buffer.
function M.last_buffer()
  if last_buffer and _BUFFERS[last_buffer] then
    view:goto_buffer(last_buffer)
  end
end

-- c++

function M.insert_namespace()
  local value, button = ui.dialogs.input({
    title = 'Insert Namespace',
    text = '',
    button1 = 'OK',
    button2 = 'Cancel',
    return_button = true,
  })
  if button == 1 then
    buffer:begin_undo_action()
    buffer:add_text('namespace ' .. value)
    buffer:new_line()
    buffer:add_text('{')
    buffer:new_line()
    buffer:new_line()
    buffer:add_text('} // namespace ' .. value)
    buffer:line_up()
    buffer:tab()
    buffer:end_undo_action()
  end
end

function M.toggle_header()
  local filename, ext = buffer.filename:match('^(.+%.)(.+)$')
  if not ext then return end
  local extensions = ext:find('^h') and {'cpp', 'cc', 'c', 'cxx'} or {'h', 'hpp', 'hxx'}
  for _, ex in pairs(extensions) do
    local fn = filename .. ex
    if lfs.attributes(fn) then
      io.open_file(fn)
      return
    end
  end
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
  if tab then
    buffer:tab()
  end
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
  local column = math.huge

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

function M.format_buffer()
  buffer:begin_undo_action()
  filename = buffer.filename
  lang = buffer:get_lexer(true)
  if not filename or not lang then return end
  if lang == 'cpp' then
    os.spawn('clang-format -i -style=file -fallback-style=none "' .. filename .. '"'):wait()
  elseif lang == 'html' then
    os.spawn('perl ' .. _USERHOME .. '/modules/util/simple_html_indent_tool.pl "' .. filename .. '"'):wait()
  end
  buffer:reload()
  buffer:end_undo_action()
end

local function find_indent(target, prev, operation)
  local origin = buffer:line_from_position(buffer.current_pos)
  local line = origin
  local function search()
    while true do
      line = prev and line - 1 or line + 1
      if line < 1 or line > buffer.line_count then
        return origin
      end
      if operation == 'eq' then
        if buffer.line_indentation[line] == target and buffer:get_line(line):match('[^%s]+') then
          return line
        end
      elseif operation == 'gt' then
        if buffer.line_indentation[line] > target and buffer:get_line(line):match('[^%s]+') then
          return line
        end
      elseif operation == 'lt' then
        if buffer.line_indentation[line] < target and buffer:get_line(line):match('[^%s]+') then
          return line
        end
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
  if buffer.selection_empty then
    textadept.editing.select_word()
  end
  ui.find.find_entry_text = buffer:get_sel_text()
  ui.find.whole_word = true
  ui.find.match_case = true
  ui.find.incremental = false
  ui.find.regex = false
  ui.find.find_in_files = false
  buffer:document_start()
  buffer:search_anchor()
  ui.find.find_next()
end

return M
