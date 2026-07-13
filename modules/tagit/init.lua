-- tagit: a Magit-inspired git porcelain for Textadept.
--
-- Public entry points:
--   require('tagit').status()           -- open the status buffer
--   require('tagit').log([ref])         -- open the log buffer
--   require('tagit').commit([amend])    -- start a commit
--   require('tagit').stash_list()       -- open the stash list buffer
--   require('tagit').branch_list([mode]) -- open the branch list buffer
--   require('tagit').reload()           -- fetch + hard reset to @{upstream}
--   require('tagit').rebase_interactive -- interactive rebase menu
--   require('tagit').console()          -- open the git console
--
-- The status buffer binds Magit-style single keys (see status.lua for the staging/navigation keys).
-- This module adds the transient menus and the public API.

local git = require('tagit.git')
local common = require('tagit.common')
local status = require('tagit.status')
local log = require('tagit.log')
local commit = require('tagit.commit')
local branch = require('tagit.branch')
local stash = require('tagit.stash')
local operation = require('tagit.operation')
local console = require('tagit.console')

local M = {}

M.git = git
M.status_module = status
M.log_module = log
M.commit_module = commit
M.stash_module = stash

-- Begin public API.

---
-- Opens the tagit status buffer for the current project.
function M.status()
  status.show()
end

---
-- Opens the tagit log buffer for the current project.
function M.log(ref)
  log.show(ref)
end

---
-- Starts a commit for the current project.
-- @param amend When true, amends the previous commit (reword).
function M.commit(amend)
  commit.start(amend)
end

---
-- Opens the tagit git console buffer for typing git commands and seeing output.
function M.console()
  console.show()
end

---
-- Opens the tagit stash list buffer for the current project.
function M.stash_list()
  stash.show()
end

---
-- Opens the tagit branch list buffer for the current project.
function M.branch_list(mode)
  branch.show(mode)
end

---
-- Asks the user to confirm, then fetches from origin for the current branch
-- and hard resets to @{upstream}. Both operations run asynchronously.
function M.reload()
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  local branch_out, branch_code = git.run('symbolic-ref --short HEAD', root)
  if not branch_out or branch_code ~= 0 then
    ui.statusbar_text = 'Cannot determine current branch'
    return
  end
  local branch_name = common.trim(branch_out)
  if
    not common.confirm(
      'Reload ' .. branch_name .. '?',
      'Fetch from origin and hard reset ' .. branch_name .. ' to @{upstream}?\n\nThis will discard all local changes.',
      'Reload'
    )
  then
    return
  end
  ui.statusbar_text = 'Fetching ' .. branch_name .. '...'
  git.run_async('fetch --no-tags origin ' .. git.quote(branch_name), root, function(out, code)
    if code ~= 0 then
      ui.statusbar_text = 'Fetch failed: ' .. common.trim(out)
      common.refresh_status()
      return
    end
    ui.statusbar_text = 'Resetting ' .. branch_name .. '...'
    git.run_async('reset --hard @{upstream}', root, function(out2, code2)
      if code2 == 0 then
        ui.statusbar_text = 'Reloaded ' .. branch_name
      else
        ui.statusbar_text = 'Reset failed: ' .. common.trim(out2)
      end
      common.refresh_status()
    end)
  end)
end

---
-- Starts an interactive rebase. Prompts for the base (e.g. HEAD~3) when called without argument.
-- @param base Optional base revision for the rebase.
M.rebase_interactive = operation.rebase_interactive

return M
