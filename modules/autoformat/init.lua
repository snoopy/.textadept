local M = {}

M.state = {}

function M.toggle_autoformat()
  local lang = buffer:get_lexer(true)

  if not lang then
    return
  end

  if M.state[lang] == nil then
    return
  end

  M.state[lang] = not M.state[lang]
  ui.statusbar_text = 'AutoFormat for "' .. lang .. '" is now: ' .. (M.state[lang] and 'ON' or 'OFF')
end

function M.format_buffer(filename)
  local lang = buffer:get_lexer(true)
  if not filename or not lang then return end

  local formatters = {}
  formatters['cpp'] = 'clang-format -i -style=file -fallback-style=none'
  formatters['python'] = 'black -l 120'

  buffer:begin_undo_action()
  os.spawn(formatters[lang] .. ' "' .. filename .. '"'):wait()
  buffer:reload()
  buffer:end_undo_action()
end

events.connect(events.FILE_AFTER_SAVE, function(filename)
  if M.state[buffer.lexer_language] then
    M.format_buffer(filename)
  end
end)

return M
