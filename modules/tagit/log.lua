-- The tagit log buffer: a read-only Textredux buffer listing recent commits, one per line,
-- with each field (hash, date, relative age, author, subject, refs) styled separately.
-- Selecting a commit opens its full diff.
--
-- The git format separates fields with a Unit Separator (0x1f) control byte rather than spaces, so fields containing spaces
-- (dates, names, subjects) split cleanly and multibyte author names cannot throw off column detection.

local reduxbuffer = require('textredux.core.buffer')
local reduxstyle = require('textredux.core.style')
local common = require('tagit.common')
local git = require('tagit.git')
local help = require('tagit.help')
local diff = require('tagit.diff')
local cherry = require('tagit.cherry_pick')
local revert = require('tagit.revert')
local transient = require('tagit.transient')

local M = {
  --- Maximum number of commits to display in the log buffer.
  max_commits = 200,
}

-- Per-field styles, derived from the theme's base styles.
-- Defined on the style module (not as locals) so Textredux (re)activates them whenever a buffer is created.
reduxstyle.tagit_log_sha = reduxstyle.class .. {}
reduxstyle.tagit_log_date = reduxstyle.nothing .. {}
reduxstyle.tagit_log_rel = reduxstyle.number .. {}
reduxstyle.tagit_log_author = reduxstyle['function'] .. {}
reduxstyle.tagit_log_refs = reduxstyle.type .. { bold = true }
reduxstyle.tagit_log_dim = reduxstyle.nothing .. {}
reduxstyle.tagit_log_error = reduxstyle.error .. {}

-- Field separator emitted by git's `%x1f` placeholder.
local SEP = string.char(31)

local buf = reduxbuffer.new('*tagit: log*')
buf.data = {}

-- Keys mode for diff buffers opened from the log. `q`/`esc` close the buffer.
local DIFF_MODE = 'tagit_log_diff'
keys[DIFF_MODE] = setmetatable({
  q = function()
    buffer:close(true)
  end,
  esc = function()
    buffer:close(true)
  end,
}, { __index = keys })

local function update_diff_keys_mode()
  if buffer._tagit_log_diff then
    keys.mode = DIFF_MODE
  elseif keys.mode == DIFF_MODE then
    keys.mode = nil
  end
end
events.connect(events.BUFFER_AFTER_SWITCH, update_diff_keys_mode)
events.connect(events.VIEW_AFTER_SWITCH, update_diff_keys_mode)

-- Render one commit as a styled, clickable line.
local function commit_at_cursor()
  local line = buf:line_from_position(buf.current_pos)
  local hashes = buf.data.hashes
  return hashes and hashes[line]
end

local function add_commit_line(b, hash, date, rel, author, subject, refs)
  local start = b.current_pos
  b:add_text(hash:sub(1, 9) .. ' ', reduxstyle.tagit_log_sha)
  b:add_text(date .. '  ', reduxstyle.tagit_log_date)
  b:add_text(common.fit(rel, 13) .. ' ', reduxstyle.tagit_log_rel)
  b:add_text(common.fit(author, 16) .. ' ', reduxstyle.tagit_log_author)
  b:add_text(subject) -- default foreground
  if refs ~= '' then b:add_text(' ' .. refs, reduxstyle.tagit_log_refs) end
  b:add_text('\n')
  b:add_hotspot(start, b.current_pos, function()
    diff.show_commit(hash, b.data.root, 'log')
  end)
end

buf.on_refresh = function(b)
  b.data.root = common.root(b.origin_buffer and b.origin_buffer.filename)
  if not b.data.root then
    b:add_text('Not in a git repository.\n', reduxstyle.tagit_log_dim)
    return
  end
  local ref = b.data.ref
  local extra_args = b.data.extra_args
  local file_path = b.data.file_path
  b.name = ref and '*tagit: log (' .. ref .. ')*' or '*tagit: log*'
  if file_path then
    local leaf = file_path:match('[^/\\]+$') or file_path
    b.name = b.name:gsub('%*$', '') .. (ref and ', ' or '') .. leaf .. ')*'
  end
  -- stylua: ignore start
  local fmt = 'format:%H'
      .. SEP .. '%cd'
      .. SEP .. '%cr'
      .. SEP .. '%cn'
      .. SEP .. '%s'
      .. SEP .. '%d'
  local ref_arg = ref and ' ' .. git.quote(ref) or ''
  local extra_arg_str = extra_args and ' ' .. extra_args or ''
  local file_arg = file_path and ' --follow -- ' .. git.quote(file_path) or ''
  local out = git.run(
      'log --date-order --date='
      .. git.quote('format:%Y-%m-%d %H:%M')
      .. ' --pretty='
      .. git.quote(fmt)
      .. extra_arg_str
      .. ' -n ' .. M.max_commits
      .. ref_arg
      .. file_arg,
      b.data.root
  )
  -- stylua: ignore end
  if not out then
    b:add_text('git log failed\n', reduxstyle.tagit_log_error)
    return
  end
  b.data.hashes = {}
  for l in (out .. '\n'):gmatch('(.-)\n') do
    if l ~= '' then
      local fields = {}
      for field in (l .. SEP):gmatch('(.-)' .. SEP) do
        fields[#fields + 1] = field
      end
      local hash = fields[1]
      if hash and hash ~= '' then
        b.data.hashes[#b.data.hashes + 1] = hash
        -- git prefixes `%d` with a space when refs are present; strip it.
        local refs = (fields[6] or ''):gsub('^%s+', '')
        add_commit_line(b, hash, fields[2] or '', fields[3] or '', fields[4] or '', fields[5] or '', refs)
      end
    end
  end

  b:add_text('\n')
  b:add_text('Press ? for keybindings\n', reduxstyle.tagit_log_dim)

  -- Restore the caret to the previously focused line, or the top on first open.
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

-- Remember the caret line whenever leaving the log buffer, so it is restored when returning (e.g. after opening a
-- commit's diff and switching back, which triggers a Textredux rebuild that would otherwise reset the caret).
events.connect(events.BUFFER_BEFORE_SWITCH, function()
  if buf:is_active() then buf.data.want_line = buf:line_from_position(buf.current_pos) end
end)

-- Key registry for the `?` help overlay.
local keymap = {}
local function bind(key, group, help_text, fn)
  if fn then buf.keys[key] = fn end
  keymap[#keymap + 1] = { key = key, group = group, help = help_text }
end

bind('\n', 'Navigate', 'show commit') -- RET: bound by Textredux
bind('g', 'Navigate', 'refresh', refresh)
bind('q', 'Navigate', 'quit', function()
  buf:close()
end)
bind('esc', 'Navigate', 'quit') -- bound by Textredux
bind('?', 'Help', 'help', function()
  help.show('tagit log', keymap)
end)
bind('A', 'Actions', 'cherry-pick', function()
  local hash = commit_at_cursor()
  if not hash then
    ui.statusbar_text = 'No commit at cursor'
    return
  end
  cherry.pick_from_log(hash)
  refresh()
end)
bind('R', 'Actions', 'rebase interactive here', function()
  local hash = commit_at_cursor()
  if not hash then
    ui.statusbar_text = 'No commit at cursor'
    return
  end
  require('tagit').rebase_interactive(hash .. '^')
  refresh()
end)
bind('V', 'Actions', 'revert commit', function()
  local hash = commit_at_cursor()
  if not hash then
    ui.statusbar_text = 'No commit at cursor'
    return
  end
  revert.revert_from_log(hash)
  refresh()
end)

---
-- The log buffer instance.
M.buffer = buf

---
-- Shows the log buffer for the current project.
-- @param ref Optional branch or ref to show log for (default: HEAD).
-- @param extra_args Optional pre-quoted extra git log arguments (e.g. author, grep filters).
-- @param file_path Optional file path to show history for (uses --follow).
function M.show(ref, extra_args, file_path)
  if ref ~= buf.data.ref or extra_args ~= buf.data.extra_args or file_path ~= buf.data.file_path then
    buf.data.want_line = nil
  end
  buf.data.ref = ref or nil
  buf.data.extra_args = extra_args or nil
  buf.data.file_path = file_path or nil
  buf:show()
end

-- Log filtering helpers used by the transient menu.

local function log_normal()
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  M.show()
end

local function log_by_author()
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  local input, button = ui.dialogs.input({
    title = 'Filter by author',
    button1 = 'OK',
    button2 = 'Cancel',
    return_button = true,
  })
  if button ~= 1 or not input or input == '' then return end
  M.show(nil, '--regexp-ignore-case --author=' .. git.quote(input))
end

local function log_by_pickaxe()
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  local input, button = ui.dialogs.input({
    title = 'Pickaxe search (-G)',
    button1 = 'OK',
    button2 = 'Cancel',
    return_button = true,
  })
  if button ~= 1 or not input or input == '' then return end
  M.show(nil, '--regexp-ignore-case -G' .. git.quote(input))
end

local function log_by_grep()
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  local input, button = ui.dialogs.input({
    title = 'Grep commit messages',
    button1 = 'OK',
    button2 = 'Cancel',
    return_button = true,
  })
  if button ~= 1 or not input or input == '' then return end
  M.show(nil, '--regexp-ignore-case --grep=' .. git.quote(input))
end

local function log_by_file()
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  local out = git.run('ls-files', root)
  if not out then return end
  local files = {}
  for f in (out .. '\n'):gmatch('(.-)\n') do
    if f ~= '' then files[#files + 1] = f end
  end
  common.pick('Tracked files', files, function(file)
    if file then M.show(nil, nil, file) end
  end)
end

--- Opens a transient log filtering menu.
function M.menu()
  transient.open('Log', {
    { key = 'l', help = 'log', action = log_normal },
    { key = 'a', help = 'filter log by author', action = log_by_author },
    { key = 'd', help = 'filter log by diff (-G)', action = log_by_pickaxe },
    { key = 'm', help = 'filter log by message', action = log_by_grep },
    { key = 'f', help = 'filter log by file', action = log_by_file },
  })
end

--- Shows the log buffer (unfiltered).
M.show_log = log_normal

--- Shows the log buffer filtered by author (prompts for input).
M.show_by_author = log_by_author

--- Shows the log buffer filtered by pickaxe --diff (-G, prompts for input).
M.show_by_pickaxe = log_by_pickaxe

--- Shows the log buffer filtered by commit message (prompts for input).
M.show_by_grep = log_by_grep

--- Shows the log buffer filtered by file (picks from tracked files).
M.show_by_file = log_by_file

return M
