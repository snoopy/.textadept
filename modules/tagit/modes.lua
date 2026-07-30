-- Centralized buffer-mode registry for tagit.
-- Each consumer module registers its buffer flag → keys mode mapping once at load time.
-- On buffer/view switch, the registry checks all flags and sets the appropriate mode.

local M = {}

local registry = {}

function M.register(buffer_flag, mode_name)
  registry[buffer_flag] = mode_name
end

function M.update()
  for flag, mode in pairs(registry) do
    if buffer[flag] then
      keys.mode = mode
      return
    end
  end
  for _, mode in pairs(registry) do
    if keys.mode == mode then
      keys.mode = nil
      return
    end
  end
end

events.connect(events.BUFFER_AFTER_SWITCH, M.update)
events.connect(events.VIEW_AFTER_SWITCH, M.update)

return M
