local M = {}

local jump_history = {}

events.connect(events.INITIALIZED, function()
  jump_history = {}
end)

events.connect(events.UPDATE_UI, function(updated)
  if not (updated & buffer.UPDATE_SELECTION) then return end

  local file = buffer.filename

  if not file then return end

  if not jump_history[file] then
    jump_history[file] = {}
  end

  local line = buffer.line_from_position(buffer.current_pos)

  local i = #jump_history[file]
  if jump_history[file][i] == line then return end

  jump_history[file][i + 1] = line
end)

function M.set()
  local file = buffer.filename
  table.remove(jump_history[file], #jump_history[file])
  local i = #jump_history[file]
  local line = jump_history[file][i]

  if not line then return end
  buffer:goto_line(line)
  view:vertical_center_caret()
  buffer:vc_home()
end

return M
