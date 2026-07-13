-- Push transient menu for tagit.

local common = require('tagit.common')
local transient = require('tagit.transient')

local M = {}

function M.menu()
  transient.open('Push', {
    {
      key = 'p',
      help = 'push',
      action = function()
        common.run_async('push', 'push')
      end,
    },
    {
      key = 'f',
      help = 'force push',
      action = function()
        if common.confirm('Force push?', 'Force push may overwrite remote history. Proceed?', 'Force Push') then
          common.run_async('push --force', 'force push')
        end
      end,
    },
    {
      key = 'i',
      help = 'initial push',
      action = function()
        if
          common.confirm(
            'Push new branch?',
            'Push the current branch to origin and set upstream?',
            'Push',
            'dialog-question'
          )
        then
          common.run_async('push --set-upstream origin HEAD', 'initial push')
        end
      end,
    },
  })
end

return M
