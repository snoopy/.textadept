-- The tagit stash buffer: a read-only Textredux buffer listing all stash entries.
-- Pressing Enter on a stash entry opens its full diff in a diff-lexer buffer.

local reduxbuffer = require('textredux.core.buffer')
local reduxstyle = require('textredux.core.style')
local common = require('tagit.common')
local git = require('tagit.git')
local help = require('tagit.help')
local transient = require('tagit.transient')

local M = {}

-- Stash ref style.
reduxstyle.tagit_stash_ref = reduxstyle.class .. {}
reduxstyle.tagit_stash_dim = reduxstyle.nothing .. {}

local buf = reduxbuffer.new('*tagit: stashes*')
buf.data = {}

-- Keys mode for diff buffers opened from the stash list.
local DIFF_MODE = 'tagit_stash_diff'
keys[DIFF_MODE] = setmetatable({
  q = function()
    buffer:close(true)
  end,
  esc = function()
    buffer:close(true)
  end,
}, { __index = keys })

local function update_diff_keys_mode()
  if buffer._tagit_stash_diff then
    keys.mode = DIFF_MODE
  elseif keys.mode == DIFF_MODE then
    keys.mode = nil
  end
end
events.connect(events.BUFFER_AFTER_SWITCH, update_diff_keys_mode)
events.connect(events.VIEW_AFTER_SWITCH, update_diff_keys_mode)

-- Show a single stash entry's diff in a normal buffer with the diff lexer.
local function show_stash(ref)
  local root = buf.data.root
  local out = git.stash_show(ref, root)
  if out == '' then
    ui.statusbar_text = 'No tracked changes in ' .. ref
    return
  end
  buffer.new()
  buffer._tagit_stash_diff = true
  buffer:set_lexer('diff')
  buffer:add_text(out)
  buffer:goto_pos(1)
  buffer:set_save_point()
  keys.mode = DIFF_MODE
end

-- Render one stash entry as a hotspot line with metadata for cursor-based actions.
local function add_stash_line(b, ref, subject)
  local lnum = b:line_from_position(b.current_pos)
  local start = b.current_pos
  b:add_text(ref .. ' ', reduxstyle.tagit_stash_ref)
  b:add_text(subject .. '\n')
  b.data.lines[lnum] = { ref = ref, subject = subject }
  b:add_hotspot(start, b.current_pos, function()
    show_stash(ref)
  end)
end

buf.on_refresh = function(b)
  b.data.lines = {}
  b.data.root = common.root(b.origin_buffer and b.origin_buffer.filename)
  if not b.data.root then
    b:add_text('Not in a git repository.\n', reduxstyle.tagit_stash_dim)
    return
  end
  local stashes = git.stashes(b.data.root)
  if #stashes == 0 then
    b:add_text('No stashes.\n', reduxstyle.tagit_stash_dim)
  else
    for _, stash in ipairs(stashes) do
      add_stash_line(b, stash.ref, stash.subject)
    end
  end
  b:add_text('\n')
  b:add_text('Press ? for keybindings\n', reduxstyle.tagit_stash_dim)
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

-- Remember the caret line whenever leaving the stash buffer.
events.connect(events.BUFFER_BEFORE_SWITCH, function()
  if buf:is_active() then buf.data.want_line = buf:line_from_position(buf.current_pos) end
end)

-- Returns the stash metadata for the line under the cursor, or nil.
local function entry_at_point()
  return buf.data.lines[buf:line_from_position(buf.current_pos)]
end

---
-- Stash push with optional message and extra git args.
-- Shows an input dialog for a stash message (may be left blank).
-- @param extra_args Optional string of extra git arguments, e.g. `'--keep-index'`.
local function stash_push(extra_args)
  local root = common.root()
  if not root then return end
  local msg, btn = ui.dialogs.input({
    title = 'Stash message (optional)',
    button1 = 'Stash',
    button2 = 'Cancel',
    return_button = true,
  })
  if btn ~= 1 or not msg then return end
  local cmd = 'stash push'
  if msg ~= '' then cmd = cmd .. ' -m ' .. git.quote(msg) end
  if extra_args then cmd = cmd .. ' ' .. extra_args end
  git.run_interactive(cmd, root, git.date_env(), function(out, code)
    common.report_git(out, code)
    common.refresh_status()
  end)
end

---
-- Opens the stash transient menu
function M.menu()
  local root = common.root()
  transient.open('Stash', {
    {
      key = 'p',
      help = 'push',
      action = function()
        stash_push(nil)
      end,
    },
    {
      key = 'k',
      help = 'push --keep-index',
      action = function()
        stash_push('--keep-index')
      end,
    },
    {
      key = 'u',
      help = 'push --include-untracked',
      action = function()
        stash_push('--include-untracked')
      end,
    },
    {
      key = 'A',
      help = 'push --all',
      action = function()
        stash_push('--all')
      end,
    },
    {
      key = 's',
      help = 'push --staged',
      action = function()
        stash_push('--staged')
      end,
    },
    {
      key = 'P',
      help = 'pop',
      action = function()
        common.report_git(git.run('stash pop', root))
        common.refresh_status()
      end,
    },
    {
      key = 'a',
      help = 'apply',
      action = function()
        common.report_git(git.run('stash apply', root))
        common.refresh_status()
      end,
    },
    {
      key = 'l',
      help = 'list stashes',
      action = function()
        M.show()
      end,
    },
    {
      key = 'c',
      help = 'clear all',
      action = function()
        if
          common.confirm(
            'Clear all stashes?',
            'This permanently deletes every stash entry.\nThis cannot be undone.',
            'Clear All'
          )
        then
          common.report_git(git.run('stash clear', root))
          common.refresh_status()
        end
      end,
    },
  })
end

-- Apply the stash under the cursor.
local function apply_stash()
  local entry = entry_at_point()
  if not entry then return end
  local out, code = git.run('stash apply ' .. git.quote(entry.ref), buf.data.root)
  common.report_git(out, code)
  if code == 0 then
    ui.statusbar_text = 'Applied ' .. entry.ref
    common.refresh_status()
  end
  refresh()
end

-- Pop (apply + drop) the stash under the cursor.
local function pop_stash()
  local entry = entry_at_point()
  if not entry then return end
  local out, code = git.run('stash pop ' .. git.quote(entry.ref), buf.data.root)
  common.report_git(out, code)
  if code == 0 then
    ui.statusbar_text = 'Popped ' .. entry.ref
    common.refresh_status()
  end
  refresh()
end

-- Drop the stash under the cursor (with confirmation).
local function drop_stash()
  local entry = entry_at_point()
  if not entry then return end
  if not common.confirm('Drop stash?', 'Drop ' .. entry.ref .. '?', 'Drop') then return end
  local out, code = git.run('stash drop ' .. git.quote(entry.ref), buf.data.root)
  common.report_git(out, code)
  if code == 0 then ui.statusbar_text = 'Dropped ' .. entry.ref end
  refresh()
end

-- Key registry for the `?` help overlay.
local keymap = {}
local function bind(key, group, help_text, fn)
  if fn then buf.keys[key] = fn end
  keymap[#keymap + 1] = { key = key, group = group, help = help_text }
end

bind('\n', 'Navigate', 'show diff') -- RET: bound by Textredux
bind('g', 'Navigate', 'refresh', refresh)
bind('q', 'Navigate', 'quit', function()
  buf:close()
end)
bind('esc', 'Navigate', 'quit') -- bound by Textredux
bind('?', 'Help', 'help', function()
  help.show('tagit stashes', keymap)
end)
bind('a', 'Actions', 'apply', apply_stash)
bind('P', 'Actions', 'pop', pop_stash)
bind('d', 'Actions', 'drop', drop_stash)

---
-- The stash buffer instance.
M.buffer = buf

---
-- Shows the stash buffer for the current project.
function M.show()
  buf:show()
end

return M
