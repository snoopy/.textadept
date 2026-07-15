-- Merge / Rebase / Cherry-pick operation menus for tagit.

local git = require('tagit.git')
local common = require('tagit.common')
local transient = require('tagit.transient')
local cherry = require('tagit.cherry_pick')
local commit = require('tagit.commit')

local M = {}

local function merge_branch()
  local root = common.root()
  common.pick('Merge branch', common.branches(root), function(name)
    common.report_git(git.run('merge ' .. git.quote(name), root, git.date_env()))
    common.refresh_status()
  end)
end

local function rebase_interactive(base)
  local root = common.root()
  if not base then
    local name, button = ui.dialogs.input({
      title = 'Rebase interactive (e.g. HEAD~3)',
      button1 = 'OK',
      button2 = 'Cancel',
      return_button = true,
    })
    if button ~= 1 or not name or name == '' then return end
    base = name
  end
  common.report_git(git.run('rebase --interactive ' .. git.quote(base), root, git.date_env()))
  common.refresh_status()
end

local function continue_operation()
  local root = common.root()
  local op = git.operation(root)
  if not op then
    ui.statusbar_text = 'No operation in progress'
    return
  end
  if op.type == 'rebase' then
    common.report_git(git.run('rebase --continue', root, git.date_env()))
  else
    commit.start(false)
    return
  end
  common.refresh_status()
end

local function abort_operation()
  local root = common.root()
  local op = git.operation(root)
  if not op then
    ui.statusbar_text = 'No operation in progress'
    return
  end
  if op.type == 'rebase' then
    if common.confirm('Abort rebase?', 'Abort the current rebase?', 'Abort') then
      common.report_git(git.run('rebase --abort', root))
      common.refresh_status()
    end
  else
    if common.confirm('Abort merge?', 'Abort the current merge?', 'Abort') then
      common.report_git(git.run('merge --abort', root))
      common.refresh_status()
    end
  end
end

local function skip_operation()
  local root = common.root()
  local op = git.operation(root)
  if not op or op.type ~= 'rebase' then
    ui.statusbar_text = 'Not in a rebase'
    return
  end
  common.report_git(git.run('rebase --skip', root, git.date_env()))
  common.refresh_status()
end

function M.menu()
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  local op = git.operation(root)
  local title, bindings
  if op then
    if op.type == 'cherry-pick' then
      title = 'Cherry-pick (in progress)'
      bindings = {
        { key = 'c', help = 'continue', action = cherry.continue },
        { key = 'a', help = 'abort', action = cherry.abort },
        { key = 's', help = 'skip', action = cherry.skip },
      }
    else
      title = op.type == 'rebase' and 'Rebase' or 'Merge'
      bindings = {
        { key = 'c', help = 'continue', action = continue_operation },
        { key = 'a', help = 'abort', action = abort_operation },
      }
      if op.type == 'rebase' then bindings[#bindings + 1] = { key = 's', help = 'skip', action = skip_operation } end
    end
  else
    title = 'Merge / Rebase'
    bindings = {
      { key = 'm', help = 'merge', action = merge_branch },
      { key = 'r', help = 'rebase interactive', action = rebase_interactive },
    }
  end
  transient.open(title, bindings)
end

M.rebase_interactive = rebase_interactive

return M
