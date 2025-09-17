local M = {}

local favorites = {}
local save_location = _USERHOME .. '/favorites'

events.connect(events.INITIALIZED, function()
  local f = io.open(save_location, 'r')
  if not f then return end

  for line in f:lines() do
    if not line:match('^$') then table.insert(favorites, line) end
  end

  f:close()
end)

events.connect(events.QUIT, function()
  if next(favorites) == nil then return end

  local f = io.open(save_location, 'w')
  if not f then return end

  for _i, v in ipairs(favorites) do
    f:write(v .. '\n')
  end

  f:close()
end, 1)

function M.toggle()
  for i, v in ipairs(favorites) do
    if v == buffer.filename then
      table.remove(favorites, i)
      ui.statusbar_text = 'Removed favorite'
      return
    end
  end
  table.insert(favorites, buffer.filename)
  ui.statusbar_text = 'Added favorite'
end

function M.show()
  if #favorites == 0 then return end
  local index = ui.dialogs.list({ title = 'Favorites', items = favorites })
  if not index then return end
  if not lfs.attributes(favorites[index]) then
    local button = ui.dialogs.message({
      title = 'Remove Favorite?',
      text = 'File not found, remove favorite?\n(' .. favorites[index] .. ')',
      icon = 'dialog-question',
      button1 = 'Yes',
      button2 = 'No',
    })
    if button == 2 then return end
    table.remove(favorites, index)
    return
  end
  io.open_file(favorites[index])
end

return M
