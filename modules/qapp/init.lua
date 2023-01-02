local M = {}

local jumplist = {}
local installdir = _USERHOME .. '/modules/qapp/session'

local function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

events.connect(events.INITIALIZED, function()
  local f = io.open(installdir, 'r')
  if not f then return end

  for line in f:lines() do
    local parts = {}
    for str in line:gmatch('([^,]+)') do
      str = str:gsub('\n$', '')
      parts[#parts + 1] = str
    end

    local root = parts[1]
    local i = tonumber(parts[2])
    local file = parts[3]
    local ln = tonumber(parts[4])

    if not lfs.attributes(file) then goto next end

    if not jumplist[root] then
      jumplist[root] = {}
    end

    if not jumplist[root][i] then
      jumplist[root][i] = {}
    end

    jumplist[root][i] = {file, ln}

    ::next::
  end

  f:close()
end)

events.connect(events.QUIT, function()
  local f = io.open(installdir, 'w')
  if not f then return end

  for project, slots in pairs(jumplist) do
    for k, file in pairs(slots) do
      f:write(project .. ',' .. k .. ',' .. file[1] .. ',' .. file[2] .. '\n')
    end
  end

  f:close()
end, 1)

function M.set(i)
  local root = io.get_project_root(buffer.filename, true)
  if not root then return end
  local linenum = buffer.line_from_position(buffer.current_pos)

  if not jumplist[root] then
    jumplist[root] = {}
  end
  if not jumplist[root][i] then
    jumplist[root][i] = {}
  end

  jumplist[root][i] = {buffer.filename, linenum}
  ui.statusbar_text = 'quick access [' .. i .. '] = ' .. buffer.filename .. ':' .. linenum
end

function M.go(i)
  local root = io.get_project_root(buffer.filename, true)
  if not root then return end
  if not jumplist[root] then return end
  if not jumplist[root][i] then return end
  io.open_file(jumplist[root][i][1])
  buffer.goto_line(jumplist[root][i][2])
  view:vertical_center_caret()
end

return M
