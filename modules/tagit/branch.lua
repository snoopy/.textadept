-- The tagit branch list buffer: a read-only Textredux buffer listing repository branches,
-- one per line, with each field styled separately.
-- Selecting a branch switches to it.

local reduxbuffer = require('textredux.core.buffer')
local reduxstyle = require('textredux.core.style')
local git = require('tagit.git')
local common = require('tagit.common')
local help = require('tagit.help')
local transient = require('tagit.transient')
local log = require('tagit.log')

local M = {}

-- Per-field styles, derived from the theme's base styles.
reduxstyle.tagit_branch_mark = reduxstyle.keyword .. {}
reduxstyle.tagit_branch_name = reduxstyle.nothing .. {}
reduxstyle.tagit_branch_sha = reduxstyle.preproc .. {}
reduxstyle.tagit_branch_date = reduxstyle.nothing .. {}
reduxstyle.tagit_branch_rel = reduxstyle.number .. {}
reduxstyle.tagit_branch_author = reduxstyle['function'] .. {}
reduxstyle.tagit_branch_upstream = reduxstyle['function'] .. {}
reduxstyle.tagit_branch_tracking = reduxstyle.keyword .. {}
reduxstyle.tagit_branch_dim = reduxstyle.nothing .. {}
reduxstyle.tagit_branch_error = reduxstyle.error .. {}

-- Field separator: literal Unit Separator byte (0x1f) embedded directly in the format string.
local SEP = string.char(31)

-- Format for branch listing (machine-parseable, US-separated).
local BRANCH_ARGS = '--sort=-committerdate --format='
  .. git.quote(
    '%(HEAD)'
      .. SEP
      .. '%(objectname:short)'
      .. SEP
      .. '%(committerdate:short)'
      .. SEP
      .. '%(committerdate:relative)'
      .. SEP
      .. '%(committername)'
      .. SEP
      .. '%(refname:short)'
      .. SEP
      .. '%(upstream:short)'
      .. SEP
      .. '%(upstream:track)'
  )

-- Helpers for branch transient menus.

local function current_branch_name(root)
  local out = git.run('branch --show-current', root) or ''
  return common.trim(out)
end

local function remote_branches(root)
  local out = git.run('branch --remotes ' .. git.quote('--format=%(refname:short)'), root) or ''
  local list = {}
  for name in out:gmatch('[^\n]+') do
    if name ~= '' then list[#list + 1] = name end
  end
  return list
end

-- Return remote branch names from 'origin' without the remote prefix.
local function origin_branch_names(root)
  local out = git.run("for-each-ref --format='%(refname:lstrip=3)' refs/remotes/origin", root) or ''
  local list = {}
  for name in out:gmatch('[^\n]+') do
    if name ~= '' then list[#list + 1] = name end
  end
  return list
end

-- Branch transient menu and operations.

local function pick_branch()
  local root = common.root()
  local local_branches = common.branches(root)
  local rmt_branches = remote_branches(root)
  local all_branches = {}
  for _, v in ipairs(local_branches) do
    all_branches[#all_branches + 1] = v
  end
  for _, v in ipairs(rmt_branches) do
    all_branches[#all_branches + 1] = v
  end
  common.pick('Switch branch', all_branches, function(name)
    local cmd = name:find('^origin/') and 'switch --track ' or 'switch '
    common.report_git(git.run(cmd .. git.quote(name), root))
    common.refresh_status()
  end)
end

local function create_branch()
  local root = common.root()
  local name, name_btn = ui.dialogs.input({
    title = 'Create and switch branch',
    button1 = 'OK',
    button2 = 'Cancel',
    return_button = true,
  })
  if name_btn ~= 1 or not name or name == '' then return end
  local source, src_btn = ui.dialogs.input({
    title = 'Source branch (empty for current)',
    button1 = 'OK',
    button2 = 'Cancel',
    return_button = true,
  })
  if src_btn ~= 1 or not source then source = '' end
  local cmd = 'switch --create ' .. git.quote(name)
  if source ~= '' then cmd = cmd .. ' ' .. git.quote(source) end
  common.report_git(git.run(cmd, root))
  common.refresh_status()
end

local function orphan_branch()
  local root = common.root()
  local name, button = ui.dialogs.input({
    title = 'Create orphan branch',
    button1 = 'OK',
    button2 = 'Cancel',
    return_button = true,
  })
  if button ~= 1 or not name or name == '' then return end
  common.report_git(git.run('switch --orphan ' .. git.quote(name), root))
  common.refresh_status()
end

local function previous_branch()
  local root = common.root()
  common.report_git(git.run('switch -', root))
  common.refresh_status()
end

local function rename_branch()
  local root = common.root()
  common.pick('Rename branch', common.branches(root), function(old_name)
    local new_name, button = ui.dialogs.input({
      title = 'New name for ' .. old_name,
      button1 = 'OK',
      button2 = 'Cancel',
      return_button = true,
    })
    if button == 1 and new_name and new_name ~= '' then
      common.report_git(git.run('branch --move ' .. git.quote(old_name) .. ' ' .. git.quote(new_name), root))
      common.refresh_status()
    end
  end)
end

local function delete_branch()
  local root = common.root()
  local current = current_branch_name(root)
  local all_branches = common.branches(root)
  local deletable = {}
  for _, name in ipairs(all_branches) do
    if name ~= current then deletable[#deletable + 1] = name end
  end
  common.pick('Delete branch', deletable, function(name)
    if common.confirm('Delete branch?', 'Delete ' .. name .. '?', 'Delete') then
      common.report_git(git.run('branch --delete --force ' .. git.quote(name), root))
      common.refresh_status()
    end
  end)
end

local function delete_remote_branch()
  common.pick('Delete remote branch', origin_branch_names(common.root()), function(name)
    if common.confirm('Delete remote branch?', 'Delete ' .. name .. '?', 'Delete') then
      common.run_async('push origin --delete ' .. git.quote(name), 'delete remote branch')
    end
  end)
end

local function set_upstream()
  local root = common.root()
  common.pick('Set upstream', remote_branches(root), function(name)
    common.report_git(git.run('branch --set-upstream-to ' .. git.quote(name), root))
    common.refresh_status()
  end)
end

local function unset_upstream()
  local root = common.root()
  common.report_git(git.run('branch --unset-upstream', root))
  common.refresh_status()
end

local function checkout_any_ref()
  local root = common.root()
  if not root then return end
  local ref, button = ui.dialogs.input({
    title = 'Checkout ref (branch, tag, commit, HEAD~N...)',
    button1 = 'Checkout',
    button2 = 'Cancel',
    return_button = true,
  })
  if button ~= 1 or not ref or ref == '' then return end
  ui.statusbar_text = 'Checking out ' .. ref .. '...'
  local out, code = git.run('checkout ' .. git.quote(ref), root)
  if code == 0 then
    ui.statusbar_text = 'Checked out ' .. ref
  else
    ui.statusbar_text = 'Checkout failed: ' .. common.trim(out)
  end
  common.refresh_status()
end

local function list_branches()
  M.show('local')
end

---
-- Opens the branch transient menu
function M.menu()
  transient.open('Branch', {
    { key = 's', help = 'switch', action = pick_branch },
    { key = 'n', help = 'create & switch', action = create_branch },
    { key = 'o', help = 'orphan', action = orphan_branch },
    { key = 'b', help = 'previous', action = previous_branch },
    { key = 'c', help = 'checkout any ref', action = checkout_any_ref },
    { key = 'm', help = 'rename', action = rename_branch },
    { key = 'd', help = 'delete local', action = delete_branch },
    { key = 'D', help = 'delete remote', action = delete_remote_branch },
    { key = 'u', help = 'set upstream', action = set_upstream },
    { key = 'U', help = 'unset upstream', action = unset_upstream },
    { key = 'l', help = 'local branches', action = list_branches },
    { key = 'r', help = 'remote branches', action = M.show_remotes },
  })
end

local buf = reduxbuffer.new('*tagit: branches*')
buf.data = { mode = 'local' }

-- Switch to a branch and refresh.
local function switch_to_branch(name)
  if not name or name == '' then return end
  ui.statusbar_text = 'Switching to ' .. name .. '...'
  local cmd = name:find('^origin/') and 'switch --track ' or 'switch '
  local out, code = git.run(cmd .. git.quote(name), buf.data.root)
  if code ~= 0 then
    ui.statusbar_text = common.trim(out or 'switch failed')
    return
  end
  ui.statusbar_text = 'Switched to ' .. name
  common.refresh_status()
  buf:refresh()
end

-- Render one branch as a styled, clickable line.
local function add_branch_line(b, head, sha, date, rel, author, refname, upstream, tracking)
  local start = b.current_pos
  b:add_text((head == '*' and '* ' or '  '), reduxstyle.tagit_branch_mark)
  b:add_text(sha .. '  ', reduxstyle.tagit_branch_sha)
  b:add_text(date .. ' ', reduxstyle.tagit_branch_date)
  b:add_text(common.fit(rel, 20) .. ' ', reduxstyle.tagit_branch_rel)
  b:add_text(common.fit(author, 20) .. ' ', reduxstyle.tagit_branch_author)
  b:add_text(common.fit(refname, 30) .. ' ', reduxstyle.tagit_branch_name)
  if upstream ~= '' then
    b:add_text('[' .. upstream .. ']', reduxstyle.tagit_branch_upstream)
    if tracking ~= '' then b:add_text(' ' .. tracking, reduxstyle.tagit_branch_tracking) end
  end
  b:add_text('\n')
  b.data.branch_names[b:line_from_position(start)] = refname
  b:add_hotspot(start, b.current_pos, function()
    switch_to_branch(refname)
  end)
end

buf.on_refresh = function(b)
  b.data.root = common.root(b.origin_buffer)
  if not b.data.root then
    b:add_text('Not in a git repository.\n', reduxstyle.tagit_branch_dim)
    return
  end
  local is_remote = b.data.mode == 'remote'
  b.name = is_remote and '*tagit: branches (remote)*' or '*tagit: branches*'
  local cmd = is_remote and 'branch --remotes ' or 'branch '
  local out = git.run(cmd .. BRANCH_ARGS, b.data.root)
  if not out then
    b:add_text('git branch failed\n', reduxstyle.tagit_branch_error)
    return
  end
  b.data.branch_names = {}
  for l in out:gmatch('[^\n]+') do
    if l ~= '' then
      local fields = {}
      for field in (l .. SEP):gmatch('(.-)' .. SEP) do
        fields[#fields + 1] = field
      end
      local sha = fields[2]
      if sha and sha ~= '' then
        add_branch_line(
          b,
          fields[1] or '',
          sha,
          fields[3] or '',
          fields[4] or '',
          fields[5] or '',
          fields[6] or '',
          fields[7] or '',
          fields[8] or ''
        )
      end
    end
  end
  b:add_text('\n')
  b:add_text('Press ? for keybindings\n', reduxstyle.tagit_branch_dim)

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

-- Helpers for branch listing buffer operations.

local function branch_at_cursor()
  local line = buf:line_from_position(buf.current_pos)
  return buf.data.branch_names and buf.data.branch_names[line]
end

local function delete_branch_at_cursor()
  local name = branch_at_cursor()
  if not name then
    ui.statusbar_text = 'Not on a branch line'
    return
  end
  local root = buf.data.root
  if not root then return end
  if name == current_branch_name(root) then
    ui.statusbar_text = 'Cannot delete current branch'
    return
  end
  if common.confirm('Delete branch?', 'Delete ' .. name .. '?', 'Delete') then
    common.report_git(git.run('branch --delete --force ' .. git.quote(name), root))
    refresh()
    common.refresh_status()
  end
end

local function delete_remote_branch_at_cursor()
  local name = branch_at_cursor()
  if not name then
    ui.statusbar_text = 'Not on a branch line'
    return
  end
  local remote_name = name:match('^origin/(.+)$')
  if not remote_name then
    ui.statusbar_text = 'Not a remote-tracking branch'
    return
  end
  if common.confirm('Delete remote branch?', 'Delete ' .. remote_name .. ' from origin?', 'Delete') then
    common.run_async('push origin --delete ' .. git.quote(remote_name), 'delete remote branch')
    refresh()
    common.refresh_status()
  end
end

local function set_upstream_at_cursor()
  local name = branch_at_cursor()
  if not name then
    ui.statusbar_text = 'Not on a branch line'
    return
  end
  local root = buf.data.root
  if not root then return end
  common.pick('Set upstream for ' .. name, remote_branches(root), function(remote)
    common.report_git(git.run('branch --set-upstream-to ' .. git.quote(remote) .. ' ' .. git.quote(name), root))
    refresh()
    common.refresh_status()
  end)
end

local function unset_upstream_at_cursor()
  local name = branch_at_cursor()
  if not name then
    ui.statusbar_text = 'Not on a branch line'
    return
  end
  local root = buf.data.root
  if not root then return end
  common.report_git(git.run('branch --unset-upstream ' .. git.quote(name), root))
  refresh()
  common.refresh_status()
end

local function rename_branch_at_cursor()
  local name = branch_at_cursor()
  if not name then
    ui.statusbar_text = 'Not on a branch line'
    return
  end
  local root = buf.data.root
  if not root then return end
  local new_name, button = ui.dialogs.input({
    title = 'Rename ' .. name .. ' to',
    button1 = 'Rename',
    button2 = 'Cancel',
    return_button = true,
  })
  if button == 1 and new_name and new_name ~= '' then
    common.report_git(git.run('branch --move ' .. git.quote(name) .. ' ' .. git.quote(new_name), root))
    refresh()
    common.refresh_status()
  end
end

local function show_log_at_cursor()
  local name = branch_at_cursor()
  if not name then
    ui.statusbar_text = 'Not on a branch line'
    return
  end
  log.show(name)
end

events.connect(events.BUFFER_BEFORE_SWITCH, function()
  if buf:is_active() then buf.data.want_line = buf:line_from_position(buf.current_pos) end
end)

-- Key registry for the `?` help overlay.
local keymap = {}
local function bind(key, group, help_text, fn)
  if fn then buf.keys[key] = fn end
  keymap[#keymap + 1] = { key = key, group = group, help = help_text }
end

bind('\n', 'Navigate', 'switch to branch', function()
  local name = branch_at_cursor()
  if name then switch_to_branch(name) end
end)
bind('g', 'Navigate', 'refresh', refresh)
bind('q', 'Navigate', 'quit', function()
  buf:close()
end)
bind('esc', 'Navigate', 'quit')
bind('?', 'Help', 'help', function()
  help.show('tagit branches', keymap)
end)
bind('d', 'Branch', 'delete', function()
  if buf.data.mode == 'remote' then
    delete_remote_branch_at_cursor()
  else
    delete_branch_at_cursor()
  end
end)
bind('r', 'View', 'toggle remote', function()
  buf.data.mode = buf.data.mode == 'local' and 'remote' or 'local'
  buf.data.want_line = nil
  buf:refresh()
end)
bind('u', 'Branch', 'set upstream', set_upstream_at_cursor)
bind('U', 'Branch', 'unset upstream', unset_upstream_at_cursor)
bind('m', 'Branch', 'rename', rename_branch_at_cursor)
bind('l', 'Branch', 'show log', show_log_at_cursor)

---
-- The branch list buffer instance.
M.buffer = buf

---
-- Shows the branch list buffer, optionally filtering to local or remote branches.
-- @param mode `'local'` (default) or `'remote'`.
function M.show(mode)
  if mode then buf.data.mode = mode end
  buf:show()
  keys.mode = buf.keys_mode
end

---
-- Shows the branch list buffer filtered to remote branches.
function M.show_remotes()
  M.show('remote')
end

return M
