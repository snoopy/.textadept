local M = {}

local last_line = buffer.line_from_position(buffer.current_pos)
local active = true
local min_line_diff = 10

events.connect(events.UPDATE_UI, function(updated)
  if not (updated & buffer.UPDATE_H_SCROLL) then return end
  local line = buffer.line_from_position(buffer.current_pos)
  if active and math.abs(last_line - line) > min_line_diff then textadept.history.record() end
  last_line = line
end)

function M.back()
  active = false
  textadept.history.back()
  view.vertical_center_caret()
  active = true
end

function M.forward()
  active = false
  textadept.history.forward()
  view.vertical_center_caret()
  active = true
end

return M
