local M = {}

local color = require('color')

local blame_active = false
local blame_lines = {}
local heatmap_active = {}

local SECONDS_PER_DAY = 86400
local SECONDS_PER_WEEK = SECONDS_PER_DAY * 7
local SECONDS_PER_MONTH = SECONDS_PER_WEEK * 30
local HEATMAP_TIMESTEPS = {
  SECONDS_PER_DAY,
  SECONDS_PER_WEEK,
  SECONDS_PER_MONTH,
  SECONDS_PER_MONTH * 2,
  SECONDS_PER_MONTH * 3,
  SECONDS_PER_MONTH * 5,
  SECONDS_PER_MONTH * 8,
  SECONDS_PER_MONTH * 13,
  SECONDS_PER_MONTH * 21,
  SECONDS_PER_MONTH * 34,
}

local HEATMAP_COLORS = {
  color.rgb2bgr('fde725'),
  color.rgb2bgr('99d83d'),
  color.rgb2bgr('4fc269'),
  color.rgb2bgr('2bac80'),
  color.rgb2bgr('22948b'),
  color.rgb2bgr('297a8e'),
  color.rgb2bgr('34618d'),
  color.rgb2bgr('3f4486'),
  color.rgb2bgr('482575'),
  color.rgb2bgr('440154'),
}

local HEATMAP_LEVELS = {}
local function make_heatmap()
  for i = 1, #HEATMAP_TIMESTEPS do
    HEATMAP_LEVELS[i] = {}
    HEATMAP_LEVELS[i]['time'] = HEATMAP_TIMESTEPS[i]
    HEATMAP_LEVELS[i]['color'] = HEATMAP_COLORS[i]
    HEATMAP_LEVELS[i]['marker'] = view.new_marker_number()
    view.marker_define(HEATMAP_LEVELS[i]['marker'], view.MARK_FULLRECT)
    view.marker_back[HEATMAP_LEVELS[i]['marker']] = HEATMAP_LEVELS[i]['color']
  end
end
make_heatmap()

local function show_git_blame()
  local current_line = buffer:line_from_position(buffer.current_pos)
  local blame_value = blame_lines[current_line]
  if blame_value == nil then return end

  buffer:eol_annotation_clear_all()
  buffer.eol_annotation_text[current_line] = blame_value
  buffer.eol_annotation_style[current_line] = buffer:style_of_name(lexer.COMMENT)
end

local function get_project_root()
  local rootpath = io.get_project_root(true)
  if not rootpath then
    ui.statusbar_text = 'Not a project'
    return nil
  end
  return rootpath
end

function M.line_diff()
  local rootpath = get_project_root()
  if not rootpath then return end
  local filename = buffer.filename
  local current_line = buffer:line_from_position(buffer.current_pos)
  local cmd = 'git -C ' .. rootpath .. ' log -p -L' .. current_line .. ',' .. current_line .. ':' .. filename
  local file = assert(io.popen(cmd, 'r'))
  local result = assert(file:read('*a'))
  file:close()
  ui.print(result)
  buffer.document_start()
  buffer:set_lexer('diff')
end

local function get_heatmap_value(time_diff)
  for i = 1, #HEATMAP_LEVELS do
    if time_diff < HEATMAP_LEVELS[i]['time'] then return HEATMAP_LEVELS[i]['marker'] end
  end
  return HEATMAP_LEVELS[#HEATMAP_LEVELS]['marker']
end

function M.heatmap()
  local rootpath = get_project_root()
  if not rootpath then return end
  local filepath = buffer.filename

  if heatmap_active[filepath] then
    for _, value in ipairs(HEATMAP_LEVELS) do
      buffer:marker_delete_all(value['marker'])
    end
    heatmap_active[filepath] = false
    return
  end

  local file = assert(io.popen('git -C ' .. rootpath .. ' blame -c ' .. filepath, 'r'))
  local lines = assert(file:read('*a'))
  file:close()

  local today = os.time()
  local current_line = 0
  for line in lines:gmatch('[^\r\n]+') do
    current_line = current_line + 1
    local commit, year, month, day, hour, min, sec =
      line:match('^(........).+(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)')
    if not commit or not year or not month or not day or not hour or not min or not sec then
      ui.print('heatmap: failed to parse line: ' .. line)
      return
    end
    if commit == '00000000' then goto continue end
    local timestamp = os.time({
      year = year,
      month = month,
      day = day,
      hour = hour,
      min = minute,
      sec = second,
    })
    local time_diff = os.difftime(today, timestamp)
    buffer:marker_add(current_line, get_heatmap_value(time_diff))
    ::continue::
  end
  heatmap_active[filepath] = true
end

function M.blame()
  local rootpath = get_project_root()
  if not rootpath then return end
  local filepath = buffer.filename

  if blame_active then
    blame_active = false
    buffer:eol_annotation_clear_all()
    return
  end

  blame_active = true

  local proc = assert(io.popen('git -C ' .. rootpath .. ' blame -c ' .. filepath, 'r'))
  local result = assert(proc:read('*a'))
  proc:close()

  for line in result:gmatch('[^\r\n]+') do
    local blame_info = line:match('%(%s*(.+)%s+%d+%)')
    if blame_info ~= nil then table.insert(blame_lines, blame_info) end
  end

  show_git_blame()
end

function M.show_rev()
  local rootpath = get_project_root()
  if not rootpath then return end
  local file = buffer.filename
  if not rootpath then return end
  rootpath = rootpath:gsub('%-', '%%-')
  file = file:gsub(rootpath, '')
  file = file:gsub('^[/\\]', '')
  file = file:gsub('[\\]', '/')

  local revision, button = ui.dialogs.input({
    title = 'Enter git revision',
    return_button = true,
  })
  if button ~= 1 then return end

  textadept.run.run_project(nil, 'git show ' .. revision .. ':' .. file)
end

events.connect(events.UPDATE_UI, function(updated)
  if not blame_active then return end
  if not (updated & buffer.UPDATE_H_SCROLL) then return end
  if #blame_lines == 0 then return end
  show_git_blame()
end)

return M
