-- Shared key-binding help overlay for the tagit buffers.
-- Renders a grouped list of bindings as a call tip, dismissed on the next keypress.

local M = {}

-- Display names for keys whose literal form is unreadable.
local KEY_NAMES = { ['\t'] = 'TAB', ['\n'] = 'RET', [' '] = 'SPC', esc = 'ESC' }

-- Order in which binding groups are displayed. Groups not listed here are appended afterwards in first-seen order.
local GROUP_ORDER = { 'Navigate', 'Stage', 'Commands', 'Help' }

local function key_name(k)
  return KEY_NAMES[k] or k
end

---
-- Shows a call tip listing the given key bindings, grouped.
-- @param title Heading shown at the top of the tip.
-- @param keymap A list of `{ key, group, help }` descriptors.
function M.show(title, keymap)
  local groups, seen = {}, {}
  for _, e in ipairs(keymap) do
    if not groups[e.group] then
      groups[e.group] = {}
      seen[#seen + 1] = e.group
    end
    local g = groups[e.group]
    g[#g + 1] = key_name(e.key) .. ' ' .. e.help
  end

  -- Display GROUP_ORDER groups first, then any others in first-seen order.
  local order, placed = {}, {}
  for _, name in ipairs(GROUP_ORDER) do
    if groups[name] then
      order[#order + 1] = name
      placed[name] = true
    end
  end
  for _, name in ipairs(seen) do
    if not placed[name] then order[#order + 1] = name end
  end

  local lines = { title, '' }
  for _, name in ipairs(order) do
    lines[#lines + 1] = string.format('%-10s %s', name, table.concat(groups[name], '   '))
  end

  pcall(function()
    view:call_tip_show(buffer.current_pos, table.concat(lines, '\n'))
  end)
end

return M
