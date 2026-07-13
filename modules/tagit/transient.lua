-- Lightweight transient menus for the tagit buffers.

local M = {}

local MODE_NAME = 'tagit_transient'

---
-- Opens a transient menu.
-- @param title A heading shown at the top of the call tip.
-- @param bindings A list of `{ key = <string>, help = <string>, action = <function> }` tables. Keys use Textadept key-string syntax.
function M.open(title, bindings)
  local prev_mode = keys.mode
  local mode = {}

  local function finish()
    keys[MODE_NAME] = nil
    keys.mode = prev_mode
    pcall(function()
      view:call_tip_cancel()
    end)
  end

  local tip = { title }
  for _, bind in ipairs(bindings) do
    tip[#tip + 1] = bind.key .. ')  ' .. bind.help
    mode[bind.key] = function()
      finish()
      bind.action()
    end
  end
  mode.esc = finish
  mode['ctrl+g'] = finish

  -- Any key not bound above dismisses the menu and is swallowed (Magit-style),
  -- rather than falling through to the global keys table.
  setmetatable(mode, {
    __index = function()
      return finish
    end,
  })

  keys[MODE_NAME] = mode
  keys.mode = MODE_NAME
  pcall(function()
    view:call_tip_show(buffer.current_pos, table.concat(tip, '\n'))
  end)
end

return M
