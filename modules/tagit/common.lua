-- Shared utilities for the tagit module.

local filteredlist = require('textredux.core.filteredlist')
local git = require('tagit.git')

local M = {}

-- Truncate `s` to `width` and pad it with spaces to that width.
-- Backs off so a multibyte UTF-8 sequence is never split.
function M.fit(s, width)
  s = s or ''
  if #s > width then
    s = s:sub(1, width)
    while #s > 0 and s:byte(#s) >= 0x80 and s:byte(#s) < 0xC0 do
      s = s:sub(1, #s - 1)
    end
    if #s > 0 and s:byte(#s) >= 0xC0 then s = s:sub(1, #s - 1) end
  end
  return s .. string.rep(' ', math.max(0, width - #s))
end

-- Strip trailing whitespace.
local function trim(s)
  return (tostring(s):gsub('%s+$', ''))
end
M.trim = trim

-- Show a confirmation dialog with Cancel. Returns true when the action button was pressed.
function M.confirm(title, text, button1, icon)
  icon = icon or 'dialog-warning'
  button1 = button1 or 'OK'
  return ui.dialogs.message({
    title = title,
    text = text,
    icon = icon,
    button1 = button1,
    button2 = 'Cancel',
  }) == 1
end

-- Refresh the status buffer if it is currently attached.
function M.refresh_status()
  local status = M.status_module()
  if status.refresh then status.refresh() end
end

-- Report a git.run result on the status bar when it failed.
-- Accepts (out, code) where out is the output string and code is the exit code.
-- Returns true on success (code == 0), false on failure.
-- Shows the error output (or a fallback message) on failure.
function M.report_git(out, code)
  if code == 0 then return true end
  ui.statusbar_text = trim(out or 'git command failed')
  return false
end

-- Run a (possibly slow) git command asynchronously,
-- reporting progress in the status bar and refreshing the status buffer on completion.
function M.run_async(args, label)
  local root = M.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  ui.statusbar_text = label .. '...'
  git.run_async(args, root, function(out, code)
    if code == 0 then
      ui.statusbar_text = label .. ' done'
    else
      ui.statusbar_text = label .. ' failed: ' .. trim(out or '')
    end
    M.refresh_status()
  end)
end

-- Show a list dialog and invoke `on_pick(item)` with the chosen item, or do nothing if canceled.
-- The call is deferred via filteredlist.wrap so it runs outside the current key handler.
function M.pick(title, items, on_pick)
  if #items == 0 then
    ui.statusbar_text = 'Nothing to select'
    return
  end
  filteredlist.wrap(function()
    local index = ui.dialogs.list({ title = title, items = items })
    if index and items[index] then on_pick(items[index]) end
  end)()
end

-- Return the repository's local branch names.
function M.branches(root)
  local out = git.run('branch --format=' .. git.quote('%(refname:short)'), root) or ''
  local list = {}
  for name in out:gmatch('[^\n]+') do
    if name ~= '' then list[#list + 1] = name end
  end
  return list
end

-- Lazy loader for the status module (avoids circular dependency: status -> init -> status).
function M.status_module()
  return require('tagit.status')
end

-- Get project root for given path or use various fallbacks
function M.root(path)
  if path then
    local root_from_path = git.root(path)
    if root_from_path then return root_from_path end
  end

  -- If the current buffer is a Textredux buffer (log, status, stash, branch),
  -- use the root it discovered in its own on_refresh.
  if buffer._textredux and buffer._textredux.data and buffer._textredux.data.root then
    return buffer._textredux.data.root
  end

  local sbuf = M.status_module().buffer
  if sbuf and sbuf.data and sbuf.data.root then return sbuf.data.root end

  local root_from_cwd = git.root() -- uses current buffer's filename
  if root_from_cwd then return root_from_cwd end
  return nil
end

return M
