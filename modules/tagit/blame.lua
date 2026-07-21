-- The tagit blame buffer: annotate each line of a file with the commit
-- that last modified it. Modeled after Magit's blame mode.
--
-- Shows commit hash, author, and age per line.

local reduxbuffer = require('textredux.core.buffer')
local reduxstyle = require('textredux.core.style')
local common = require('tagit.common')
local git = require('tagit.git')
local diff = require('tagit.diff')
local help = require('tagit.help')

local M = {}

-- Per-field styles.
reduxstyle.tagit_blame_sha = reduxstyle.class .. {}
reduxstyle.tagit_blame_author = reduxstyle['function'] .. {}
reduxstyle.tagit_blame_age = reduxstyle.number .. {}
reduxstyle.tagit_blame_sep = reduxstyle.nothing .. {}

-- Keys mode for diff buffers opened from the blame buffer.
local DIFF_MODE = 'tagit_blame_diff'
keys[DIFF_MODE] = setmetatable({
  q = function()
    buffer:close(true)
  end,
  esc = function()
    buffer:close(true)
  end,
}, { __index = keys })

local function update_diff_keys_mode()
  if buffer._tagit_blame_diff then
    keys.mode = DIFF_MODE
  elseif keys.mode == DIFF_MODE then
    keys.mode = nil
  end
end
events.connect(events.BUFFER_AFTER_SWITCH, update_diff_keys_mode)
events.connect(events.VIEW_AFTER_SWITCH, update_diff_keys_mode)

-- Format a Unix timestamp as a relative time string.
local function relative_time(t)
  local diff = os.time() - t
  if diff < 0 then return 'in the future' end
  if diff < 60 then return 'moments ago' end
  if diff < 3600 then return math.floor(diff / 60) .. 'm ago' end
  if diff < 86400 then return math.floor(diff / 3600) .. 'h ago' end
  if diff < 604800 then return math.floor(diff / 86400) .. 'd ago' end
  if diff < 2592000 then return math.floor(diff / 604800) .. 'w ago' end
  if diff < 31536000 then return math.floor(diff / 2592000) .. 'mo ago' end
  return math.floor(diff / 31536000) .. 'y ago'
end

local buf = reduxbuffer.new('*tagit: blame*')
buf.data = {}
buf.data.revision_stack = {}
buf.data.blame_cache = {}

buf.on_refresh = function(b)
  b.data.root = b.data.root or common.root(b.origin_buffer)
  if not b.data.root then
    b:add_text('Not in a git repository.\n', reduxstyle.tagit_blame_sep)
    return
  end
  local filepath = b.data.filepath
  if not filepath then
    b:add_text('No file specified.\n', reduxstyle.tagit_blame_sep)
    return
  end
  local revision = b.data.revision
  b.name = revision and '*tagit: blame (' .. filepath .. ' @ ' .. revision .. ')*'
    or '*tagit: blame (' .. filepath .. ')*'
  local cache_key = revision or false
  local blame_data = b.data.blame_cache[cache_key]
  local err
  if not blame_data then
    blame_data, err = git.blame(filepath, b.data.root, revision)
    if blame_data then b.data.blame_cache[cache_key] = blame_data end
  end
  if not blame_data then
    b:add_text('git blame error: ' .. tostring(err) .. '\n', reduxstyle.tagit_blame_sep)
    return
  end
  if #blame_data == 0 then
    b:add_text('No blame data for ' .. filepath .. '\n', reduxstyle.tagit_blame_sep)
    return
  end
  b.data.lines = {}
  for _, entry in ipairs(blame_data) do
    local sha = entry.sha
    local author = entry.author
    local age_text = relative_time(entry.author_time)
    local content = entry.content
    local short_sha = sha:sub(1, 9)
    local is_uncommitted = sha:match('^0+$') ~= nil
    if is_uncommitted then
      short_sha = '         '
      author = '(uncommitted)'
      age_text = ''
    end
    local lnum = b.line_count
    b:add_text(short_sha .. ' ', reduxstyle.tagit_blame_sha)
    b:add_text(common.fit(author, 16) .. '  ', reduxstyle.tagit_blame_author)
    b:add_text(common.fit(age_text, 12) .. ' ', reduxstyle.tagit_blame_age)
    b:add_text('| ', reduxstyle.tagit_blame_sep)
    b:add_text(entry.content .. '\n')
    b.data.lines[lnum] = {
      sha = sha,
      author = author,
      age_text = age_text,
      content = content,
      is_uncommitted = is_uncommitted,
    }
  end
  b:add_text('\n')
  b:add_text('Press ? for keybindings\n', reduxstyle.tagit_blame_sep)
  local want = math.max(1, math.min(b.data.want_line or 1, b.line_count))
  b:goto_line(want)
  b:vc_home()
end

-- Refresh while preserving the focused line.
local function refresh()
  if not buf:is_attached() then return end
  buf.data.want_line = buf:line_from_position(buf.current_pos)
  buf:refresh()
end

events.connect(events.BUFFER_BEFORE_SWITCH, function()
  if buf:is_active() then buf.data.want_line = buf:line_from_position(buf.current_pos) end
end)

-- Entry metadata under cursor.
local function entry_at_point()
  return buf.data.lines[buf:line_from_position(buf.current_pos)]
end

-- Show commit diff for the line under cursor.
local function show_commit()
  local entry = entry_at_point()
  if not entry or entry.is_uncommitted then
    ui.statusbar_text = 'Not on a committed line'
    return
  end
  diff.show_commit(entry.sha, buf.data.root, 'blame')
end

-- Re-blame at the parent of the current line's commit.
local function blame_parent()
  local entry = entry_at_point()
  if not entry or entry.is_uncommitted then
    ui.statusbar_text = 'Cannot go further back'
    return
  end
  buf.data.want_line = buf:line_from_position(buf.current_pos)
  local parent = git.parent_sha(entry.sha, buf.data.root)
  if not parent then
    ui.statusbar_text = 'No parent commit (root commit?)'
    return
  end
  if buf.data.revision == parent then
    ui.statusbar_text = 'Already at ' .. parent
    return
  end
  local out, code =
    git.run('ls-tree -r --name-only ' .. git.quote(parent) .. ' -- ' .. git.quote(buf.data.filepath), buf.data.root)
  if code ~= 0 or not out:match('%S') then
    ui.statusbar_text = 'File not found at ' .. parent:sub(1, 9)
    return
  end
  table.insert(buf.data.revision_stack, buf.data.revision or false)
  buf.data.revision = parent
  buf:refresh()
end

-- Re-blame at a user-specified revision.
local function blame_revision()
  local input, button = ui.dialogs.input({
    title = 'Blame at revision (Commit hash, HEAD~N, or branch name)',
    button1 = 'Blame',
    button2 = 'Cancel',
    return_button = true,
  })
  if button ~= 1 or not input or input == '' then return end
  buf.data.want_line = buf:line_from_position(buf.current_pos)
  table.insert(buf.data.revision_stack, buf.data.revision or false)
  buf.data.revision = input
  buf:refresh()
end

-- Reset blame to the initial revision (the one passed to M.show).
local function blame_home()
  local initial = buf.data.initial_revision
  if buf.data.revision == initial then
    ui.statusbar_text = 'Already at initial revision'
    return
  end
  buf.data.want_line = buf:line_from_position(buf.current_pos)
  table.insert(buf.data.revision_stack, buf.data.revision or false)
  buf.data.revision = initial
  buf:refresh()
end

-- Pop the revision stack, going back one navigation step.
local function blame_back()
  if #buf.data.revision_stack == 0 then
    ui.statusbar_text = 'No previous revision'
    return
  end
  local prev = table.remove(buf.data.revision_stack)
  if prev == false then prev = nil end
  buf.data.want_line = buf:line_from_position(buf.current_pos)
  buf.data.revision = prev
  buf:refresh()
end

-- Navigate to the previous/next same-commit chunk boundary.
local function next_chunk(dir)
  local current = buf:line_from_position(buf.current_pos)
  local lines = buf.data.lines
  local step = dir or 1
  local current_sha = lines[current] and lines[current].sha
  if not current_sha then
    ui.statusbar_text = 'Not on a blamed line'
    return
  end
  for l = current + step, step > 0 and #lines or 1, step do
    local meta = lines[l]
    if meta and meta.sha ~= current_sha then
      buf:goto_line(l)
      return
    end
  end
  ui.statusbar_text = 'No more chunks in this direction'
end

local function prev_chunk()
  next_chunk(-1)
end

-- Key registry.
local keymap = {}
local function bind(key, group, help_text, fn)
  if fn then buf.keys[key] = fn end
  keymap[#keymap + 1] = { key = key, group = group, help = help_text }
end

bind('\n', 'Navigate', 'show commit diff', show_commit)
bind('g', 'Navigate', 'refresh', refresh)
bind('q', 'Navigate', 'quit', function()
  buf:close()
end)
bind('esc', 'Navigate', 'quit')
bind('?', 'Help', 'help', function()
  help.show('tagit blame', keymap)
end)
bind('b', 'Blame', 'blame parent commit', blame_parent)
bind('r', 'Blame', 'blame at revision', blame_revision)
bind('H', 'Blame', 'back to initial revision', blame_home)
bind('h', 'Blame', 'go to previous revision', blame_back)
bind('n', 'Navigate', 'next chunk', function()
  next_chunk(1)
end)
bind('p', 'Navigate', 'prev chunk', prev_chunk)

-- Public API.

M.buffer = buf

---
-- Show blame for a file.
-- @param filepath File path relative to the repository root.
-- @param root Repository root.
-- @param revision Optional revision to blame against (default: HEAD).
-- @param lineno Optional line number to jump to.
function M.show(filepath, root, revision, lineno)
  if not filepath or not root then
    ui.statusbar_text = 'No file or repository'
    return
  end
  if filepath ~= buf.data.filepath or revision ~= buf.data.revision then buf.data.want_line = lineno end
  if filepath ~= buf.data.filepath or revision ~= buf.data.initial_revision then
    buf.data.revision_stack = {}
    buf.data.initial_revision = revision or nil
  end
  if filepath ~= buf.data.filepath then buf.data.blame_cache = {} end
  buf.data.filepath = filepath
  buf.data.root = root
  buf.data.revision = revision or nil
  buf:show()
  view:vertical_center_caret()
end

return M
