-- Revert operations for tagit.
--
-- Provides log-buffer integration for reverting a commit via git revert --no-edit.
-- The revert creates a new commit that undoes the target commit's changes.

local git = require('tagit.git')
local common = require('tagit.common')

local M = {}

---
-- Revert a specific commit (called from the log buffer).
-- @param sha The commit hash to revert.
function M.revert_from_log(sha)
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  local msg = git.run('log --oneline -1 ' .. git.quote(sha), root) or sha
  if not common.confirm('Revert commit?', 'Revert ' .. common.trim(msg) .. '?', 'Revert', 'dialog-question') then
    return
  end
  local out, code = git.revert(sha, root)
  if code == 0 then
    common.refresh_status()
  else
    ui.statusbar_text = common.trim(out or 'revert failed')
  end
end

return M
