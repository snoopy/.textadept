-- Cherry-pick operations for tagit.
--
-- Provides a transient menu, log-buffer integration, and cross-branch picking.
-- Also exposes cherry-pick continue/abort/skip for in-progress operations.

local git = require('tagit.git')
local common = require('tagit.common')
local transient = require('tagit.transient')

local M = {}

local function do_pick(sha_or_ref, root)
  local msg = git.run('log --oneline -1 ' .. git.quote(sha_or_ref), root) or sha_or_ref
  if
    not common.confirm('Cherry-pick?', 'Cherry-pick ' .. common.trim(msg) .. '?', 'Cherry-pick', 'dialog-question')
  then
    return
  end
  ui.statusbar_text = 'Cherry-picking...'
  git.run_interactive('cherry-pick ' .. git.quote(sha_or_ref), root, git.date_env(), function(out, code)
    common.report_git(out, code)
    common.refresh_status()
  end)
end

--- Prompt the user for a commit hash or ref and cherry-pick it.
function M.pick_commit()
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  local sha, button = ui.dialogs.input({
    title = 'Cherry-pick (commit hash or ref)',
    button1 = 'Cherry-pick',
    button2 = 'Cancel',
    return_button = true,
  })
  if button ~= 1 or not sha or sha == '' then return end
  do_pick(sha, root)
end

--- Pick a branch, then pick one of its unpicked commits to cherry-pick.
function M.pick_from_branch()
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  common.pick('Pick branch', common.branches(root), function(name)
    local commits = git.branch_commits(name, 30, root)
    if #commits == 0 then
      ui.statusbar_text = 'No unpicked commits on ' .. name
      return
    end
    local items = {}
    for _, c in ipairs(commits) do
      items[#items + 1] = c.sha .. ' ' .. c.subject
    end
    common.pick('Commits on ' .. name, items, function(item)
      local sha = item:match('^(%S+)')
      if sha then do_pick(sha, root) end
    end)
  end)
end

---
-- Cherry-pick a specific commit (called from the log buffer).
-- @param sha The commit hash to cherry-pick.
function M.pick_from_log(sha)
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  do_pick(sha, root)
end

--- Continue a conflicted cherry-pick after resolving conflicts.
function M.continue()
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  ui.statusbar_text = 'Continuing cherry-pick...'
  git.run_interactive('cherry-pick --continue', root, git.date_env(), function(out, code)
    common.report_git(out, code)
    common.refresh_status()
  end)
end

--- Abort a cherry-pick in progress.
function M.abort()
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  if common.confirm('Abort cherry-pick?', 'Abort the current cherry-pick operation?', 'Abort') then
    common.report_git(git.cherry_pick_abort(root))
    common.refresh_status()
  end
end

--- Skip the current commit and continue the cherry-pick sequence.
function M.skip()
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  common.report_git(git.cherry_pick_skip(root))
  common.refresh_status()
end

--- Open the cherry-pick transient menu.
function M.menu()
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  local op = git.operation(root)
  if op and op.type == 'cherry-pick' then
    transient.open('Cherry-pick (in progress)', {
      { key = 'c', help = 'continue', action = M.continue },
      { key = 'a', help = 'abort', action = M.abort },
      { key = 's', help = 'skip', action = M.skip },
    })
  else
    transient.open('Cherry-pick', {
      { key = 'p', help = 'pick commit', action = M.pick_commit },
      { key = 'b', help = 'pick from branch', action = M.pick_from_branch },
    })
  end
end

return M
