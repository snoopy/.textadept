local M = {}

-- git

local git_path = 'git'

local function popen(cmd)
  local rootpath = io.get_project_root(buffer.filename, true)
  local filepath = buffer.filename

  local file = assert(io.popen(git_path .. ' -C ' .. rootpath .. ' ' .. cmd .. ' ' .. filepath, 'r'))
  local result = assert(file:read('*a'))
  file:close()

  return result
end

function M.gitblame()
  local linenumber = buffer:line_from_position(buffer.current_pos)
  ui.print(popen('blame '))
  buffer.goto_line(linenumber)
  view:vertical_center_caret()
  view:unsplit()
end

function M.current_line_log()
  local linenumber = buffer:line_from_position(buffer.current_pos)
  local cmd = 'log -L ' .. linenumber .. ',+1:'
  ui.print(popen(cmd))
  buffer:set_lexer('diff')
  buffer:document_start()
  view:unsplit()
end

function M.log()
  local cmd = 'log '
  ui.print(popen(cmd))
  buffer:set_lexer('makefile')
  buffer:document_start()
  view:unsplit()
end

-- nav

function M.goto_nearest_occurrence(reverse)
  --local buffer = buffer

  if buffer.selection_empty then
    textadept.editing.select_word(false)
  end

  local s, e = buffer.selection_start, buffer.selection_end
  if s == e then
    s, e = buffer:word_start_position(s), buffer:word_end_position(s)
  end
  local word = buffer:text_range(s, e)
  if word == '' then
    return
  end

  buffer.search_flags = buffer.FIND_WHOLEWORD + buffer.FIND_MATCHCASE
  if reverse then
    buffer.target_start = s - 1
    buffer.target_end = 0
  else
    buffer.target_start = e + 1
    buffer.target_end = buffer.length
  end
  if buffer:search_in_target(word) == -1 then
    if reverse then
      buffer.target_start = buffer.length
      buffer.target_end = e + 1
    else
      buffer.target_start = 0
      buffer.target_end = s - 1
    end
    if buffer:search_in_target(word) == -1 then return end
  end
  buffer:set_sel(buffer.target_start, buffer.target_end)
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
    if #value > 0 then
      buffer:add_text('namespace ' .. value)
    else
      buffer:add_text('namespace')
    end
    buffer:new_line()
    buffer:add_text('{')
    buffer:new_line()
    buffer:new_line()
    if #value > 0 then
      buffer:add_text('} // namespace ' .. value)
    else
      buffer:add_text('} // anonymous namespace')
    end
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

return M
