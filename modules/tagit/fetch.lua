-- Fetch / Pull transient menu for tagit.

local common = require('tagit.common')
local transient = require('tagit.transient')

local M = {}

function M.menu()
  transient.open('Fetch / Pull', {
    {
      key = 'o',
      help = 'fetch origin (--no-tags)',
      action = function()
        common.run_async('fetch --no-tags origin', 'fetch origin')
      end,
    },
    {
      key = 'a',
      help = 'fetch all (--prune --no-tags)',
      action = function()
        common.run_async('fetch --all --no-tags --prune', 'fetch all')
      end,
    },
    {
      key = 't',
      help = 'fetch all tags',
      action = function()
        common.run_async('fetch --all --tags --prune', 'fetch all tags')
      end,
    },
    {
      key = 'f',
      help = 'pull (--ff-only)',
      action = function()
        common.run_async('pull --ff-only --no-tags', 'pull')
      end,
    },
  })
end

return M
