local M = {}

local jumplist = {}
local installdir = _USERHOME .. '/modules/quicknav/session'

events.connect(events.INITIALIZED, function()
  local filehandle = io.open(installdir, 'r')
  if not filehandle then return end

  for line in filehandle:lines() do
    local parts = {}
    for part in line:gmatch('([^,]+)') do
      parts[#parts + 1] = part:gsub('\n$', '')
    end

    local root = parts[1]
    local i = tonumber(parts[2])
    local filename = parts[3]
    local ln = tonumber(parts[4])

    if not jumplist[root] then jumplist[root] = {} end

    if not jumplist[root][i] then jumplist[root][i] = {} end

    jumplist[root][i] = { filename, ln }
  end

  filehandle:close()
end)

events.connect(events.QUIT, function()
  if next(jumplist) == nil then return end

  local filehandle = io.open(installdir, 'w')
  if not filehandle then return end

  for project, slots in pairs(jumplist) do
    for k, filename in pairs(slots) do
      filehandle:write(project .. ',' .. k .. ',' .. filename[1] .. ',' .. filename[2] .. '\n')
    end
  end

  filehandle:close()
end, 1)

function M.set(i)
  local root = io.get_project_root(buffer.filename, true)
  if not root then return end
  local linenum = buffer.line_from_position(buffer.current_pos)

  if not jumplist[root] then jumplist[root] = {} end
  if not jumplist[root][i] then jumplist[root][i] = {} end

  jumplist[root][i] = { buffer.filename, linenum }
  ui.statusbar_text = 'quick access [' .. i .. '] = ' .. buffer.filename .. ':' .. linenum
end

function M.go(i)
  local root = io.get_project_root(buffer.filename, true)
  if not root then return end
  if not jumplist[root] then return end
  if not jumplist[root][i] then return end
  if not lfs.attributes(jumplist[root][i][1]) then return end
  io.open_file(jumplist[root][i][1])
  buffer.goto_line(jumplist[root][i][2])
  view:vertical_center_caret()
  buffer:vc_home()
end

return M
