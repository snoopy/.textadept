local M = {}

M.blame_follow = false

local blame_lines = {}

local heatmap_levels = {
  [1] = {
    -- 24h == 86400s
    ['age'] = 86400,
    ['color'] = 0x3951c3,
  },
  [2] = {
    -- 1 week
    ['age'] = 86400 * 7,
    ['color'] = 0x168fe7,
  },
  [3] = {
    -- 1 month
    ['age'] = 86400 * 30,
    ['color'] = 0x01d8f7,
  },
  [4] = {
    -- 6 months
    ['age'] = 86400 * 30 * 6,
    ['color'] = 0x00ee7c,
  },
  [5] = {
    -- 1 year
    ['age'] = 86400 * 30 * 12,
    ['color'] = 0x3fc505,
  },
  [6] = {
    -- 3 years
    ['age'] = 86400 * 30 * 12 * 3,
    ['color'] = 0x959118,
  },
  [7] = {
    -- 5 years
    ['age'] = 86400 * 30 * 12 * 5,
    ['color'] = 0x7b2803,
  },
}

local function create_heatmap_markers()
  for i = 1, #heatmap_levels do
    heatmap_levels[i]['marker'] = view.new_marker_number()
    view.marker_define(heatmap_levels[i]['marker'], view.MARK_FULLRECT)
    view.marker_back[heatmap_levels[i]['marker']] = heatmap_levels[i]['color']
  end
end
create_heatmap_markers()

local function show_git_blame()
  local current_line = buffer:line_from_position(buffer.current_pos)
  local blame_value = blame_lines[current_line]
  if blame_value == nil then return end

  buffer:annotation_clear_all()
  buffer.annotation_text[current_line] = blame_value
  buffer.annotation_style[current_line] = buffer:style_of_name(lexer.COMMENT)
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
  for i = 1, #heatmap_levels do
    if time_diff < heatmap_levels[i]['age'] then
      return heatmap_levels[i]['marker']
    end
  end
  return heatmap_levels[#heatmap_levels]['marker']
end

function M.heatmap()
  local rootpath = get_project_root()
  if not rootpath then return end
  local filepath = buffer.filename

  local file = assert(io.popen('git -C ' .. rootpath .. ' blame -c ' .. filepath, 'r'))
  local result = assert(file:read('*a'))
  file:close()

  local today = os.time()

  local current_line = 1
  for line in result:gmatch('[^\r\n]+') do
    local date = {}
    date.year, date.month, date.day, date.hour, date.min, date.sec = line:match('(%d%d%d%d)-(%d%d)-(%d%d) (%d%d):(%d%d):(%d%d)')
    local timestamp = os.time(date)
    local time_diff = math.abs(os.difftime(today, timestamp))
    buffer:marker_add(current_line, get_heatmap_value(time_diff))
    current_line = current_line + 1
  end
end

function M.clear_markers()
  for _, value in ipairs(heatmap_levels) do
    buffer:marker_delete_all(value['marker'])
    buffer:annotation_clear_all()
  end
end

function M.toggle_blame_follow()
  M.blame_follow = not M.blame_follow
end

function M.blame()
  local rootpath = get_project_root()
  if not rootpath then return end
  local filepath = buffer.filename

  local file = assert(io.popen('git -C ' .. rootpath .. ' blame -c ' .. filepath, 'r'))
  local result = assert(file:read('*a'))
  file:close()

  for line in result:gmatch('[^\r\n]+') do
    table.insert(blame_lines, line)
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
  if not M.blame_follow then return end
  if not (updated & buffer.UPDATE_H_SCROLL) then return end
  if #blame_lines == 0 then return end
  show_git_blame()
end)

return M
