-- The tagit git console: an editable scratch buffer for typing git commands and seeing their output.

local git = require('tagit.git')
local common = require('tagit.common')

local M = {}

local KEYS_MODE = 'tagit_console'

-- Activate console keys mode only while a console buffer is current.
local function update_keys_mode()
  if buffer._tagit_console then
    keys.mode = KEYS_MODE
  elseif keys.mode == KEYS_MODE then
    keys.mode = nil
  end
end
events.connect(events.BUFFER_AFTER_SWITCH, update_keys_mode)
events.connect(events.VIEW_AFTER_SWITCH, update_keys_mode)

-- Run the current line as a git command and append its output.
local function execute_line()
  local line = buffer:line_from_position(buffer.current_pos)
  local text = buffer:get_line(line)
  text = text:match('^%s*(.-)%s*$')
  if not text or text == '' or text:sub(1, 1) == '#' then return end

  local root = common.root()
  if not root then
    buffer:add_text('Not a git repository\n\n')
    return
  end

  local out, code = git.run(text, root)
  buffer:add_text('$ ' .. text .. '\n')
  if out and out ~= '' then
    buffer:add_text(out)
    if out:sub(-1) ~= '\n' then buffer:add_text('\n') end
  end
  if code ~= 0 then buffer:add_text('exit code: ' .. code .. '\n') end
  buffer:add_text('\n')
  buffer:set_save_point()
  buffer:goto_pos(buffer.length)
  common.refresh_status()
end

-- Clear the console and re-add the header.
local function clear_console()
  buffer:clear_all()
  buffer:add_text('# tagit console -- type git commands and press Enter\n')
  buffer:add_text('# esc to close\n')
  buffer:add_text('\n')
  buffer:set_save_point()
end

-- Console buffer key bindings.
keys[KEYS_MODE] = setmetatable({
  ['\n'] = execute_line,
  ['ctrl+l'] = clear_console,
  esc = function()
    buffer:close(true)
  end,
}, { __index = keys })

---
-- Opens the git console buffer for the current project.
function M.show()
  local root = common.root()
  buffer.new()
  buffer._tagit_console = true
  buffer:set_lexer('bash')
  buffer.name = '*tagit: console*'
  clear_console()
  keys.mode = KEYS_MODE
end

return M
