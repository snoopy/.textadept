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
    ui.statusbar_text = 'Merging...'
    git.run_interactive('merge ' .. git.quote(name), root, git.date_env(), function(out, code)
      common.report_git(out, code)
      common.refresh_status()
    end)
  end)
end

local function rebase_interactive(base, on_done)
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
  if not root then return end
  ui.statusbar_text = 'Rebase in progress...'
  git.run_interactive('rebase --interactive ' .. git.quote(base), root, git.date_env(), function(out, code)
    common.report_git(out, code)
    common.refresh_status()
    if on_done then on_done(code) end
  end)
end

local function continue_operation()
  local root = common.root()
  local op = git.operation(root)
  if not op then
    ui.statusbar_text = 'No operation in progress'
    return
  end
  if op.type == 'rebase' then
    ui.statusbar_text = 'Continuing rebase...'
    git.run_interactive('rebase --continue', root, git.date_env(), function(out, code)
      common.report_git(out, code)
      common.refresh_status()
    end)
  else
    commit.start(false)
  end
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
  elseif op.type == 'merge' then
    if common.confirm('Abort merge?', 'Abort the current merge?', 'Abort') then
      common.report_git(git.run('merge --abort', root))
      common.refresh_status()
    end
  else
    ui.statusbar_text = 'Nothing to abort for ' .. op.type
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

local function revert_continue()
  local root = common.root()
  if not root then return end
  ui.statusbar_text = 'Continuing revert...'
  git.run_interactive('revert --continue', root, git.date_env(), function(out, code)
    common.report_git(out, code)
    common.refresh_status()
  end)
end

local function revert_abort()
  local root = common.root()
  if not root then return end
  if common.confirm('Abort revert?', 'Abort the current revert operation?', 'Abort') then
    common.report_git(git.revert_abort(root))
    common.refresh_status()
  end
end

local function revert_skip()
  local root = common.root()
  if not root then return end
  common.report_git(git.revert_skip(root))
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
    elseif op.type == 'revert' then
      title = 'Revert (in progress)'
      bindings = {
        { key = 'c', help = 'continue', action = revert_continue },
        { key = 'a', help = 'abort', action = revert_abort },
        { key = 's', help = 'skip', action = revert_skip },
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
