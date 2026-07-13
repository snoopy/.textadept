-- Reset / Clean transient menu for tagit.

local git = require('tagit.git')
local common = require('tagit.common')
local transient = require('tagit.transient')

local M = {}

function M.menu()
  transient.open('Reset / Clean', {
    {
      key = 'r',
      help = 'reload: fetch + reset @{upstream}',
      action = function()
        require('tagit').reload()
      end,
    },
    {
      key = 'n',
      help = 'nuke: reset --hard',
      action = function()
        if common.confirm('Hard reset?', 'Discard all staged and unstaged changes?', 'Nuke') then
          common.report_git(git.reset('hard', nil, common.root()))
          common.refresh_status()
        end
      end,
    },
    {
      key = 'd',
      help = 'drop: reset --hard HEAD~1',
      action = function()
        if common.confirm('Drop last commit?', 'Discard the last commit and all staged/unstaged changes?', 'Drop') then
          common.report_git(git.reset('hard', 'HEAD~1', common.root()))
          common.refresh_status()
        end
      end,
    },
    {
      key = 'u',
      help = 'undo: reset --soft HEAD~1',
      action = function()
        if common.confirm('Undo last commit?', 'Undo last commit, keeping changes staged?', 'Undo') then
          common.report_git(git.reset('soft', 'HEAD~1', common.root()))
          common.refresh_status()
        end
      end,
    },
    {
      key = 'a',
      help = 'any ref: reset --hard',
      action = function()
        local root = common.root()
        if not root then return end
        local ref, button = ui.dialogs.input({
          title = 'Reset --hard to ref (Commit hash, HEAD~N, branch name, tag...)',
          text = '',
          button1 = 'Reset',
          button2 = 'Cancel',
          return_button = true,
        })
        if button ~= 1 or not ref or ref == '' then return end
        if
          common.confirm(
            'Reset --hard?',
            'Reset --hard to ' .. ref .. '?\n\nDiscards all staged and unstaged changes.',
            'Reset'
          )
        then
          common.report_git(git.reset('hard', ref, root))
          common.refresh_status()
        end
      end,
    },
    {
      key = 'c',
      help = 'clean: clean -df',
      action = function()
        if common.confirm('Clean untracked?', 'Delete untracked files and directories?', 'Clean') then
          common.report_git(git.clean(common.root(), false))
          common.refresh_status()
        end
      end,
    },
    {
      key = 'p',
      help = 'purge: clean -dfx -f',
      action = function()
        if
          common.confirm('Purge untracked + ignored?', 'Delete ALL untracked and ignored files/directories?', 'Purge')
        then
          common.report_git(git.clean(common.root(), true))
          common.refresh_status()
        end
      end,
    },
  })
end

return M
