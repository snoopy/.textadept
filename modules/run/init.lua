local M = {}

local path_ignore_list = {
  ['external'] = true,
  ['build'] = true,
}

local function is_valid(path)
  local rootpath = io.get_project_root(true)
  if not rootpath then return end

  if not path:match(rootpath) then return end

  for k, _ in pairs(path_ignore_list) do
    if path:match(k) then return false end
  end
  return true
end

local function run_and_mark(cmd, cwd)
  local proc = os.spawn(cmd, cwd)
  if not proc then
    ui.statusbar_text = 'ERROR - failed to run: ' .. cmd
    return
  end
  local stdout = proc:read('a')

  buffer:marker_delete_all(textadept.run.MARK_WARNING)
  buffer:annotation_clear_all()

  local issues = 0
  local messages = {}

  for line in stdout:gmatch('[^\r\n]+') do
    -- Expect lines in the form: <path>:<line>: <message>
    local filepath, line_num_str, msg = line:match('^%s*(.-):(%d+)(.+)$')
    if not filepath or not line_num_str or not msg then goto continue end
    local line_num = tonumber(line_num_str)
    if not line_num then goto continue end

    local filepath_abs = lfs.abspath(filepath, cwd)
    if lfs.attributes(filepath_abs) and is_valid(filepath_abs) then
      if not messages[filepath_abs] then messages[filepath_abs] = {} end
      if not messages[filepath_abs][line_num] then messages[filepath_abs][line_num] = {} end
      table.insert(messages[filepath_abs][line_num], msg)
      -- Only count issues for valid files
      issues = issues + 1
    end

    ::continue::
  end

  for filepath_abs, line_table in pairs(messages) do
    for line_num, msg_table in pairs(line_table) do
      local all_messages = ''
      for _, msg in pairs(msg_table) do
        all_messages = all_messages .. msg .. '\n'
      end
      io.open_file(filepath_abs)
      buffer:goto_line(line_num)
      buffer.annotation_text[line_num] = all_messages:gsub('\n$', '')
      buffer.annotation_style[line_num] = buffer:style_of_name(lexer.COMMENT)
      buffer:marker_add(line_num, textadept.run.MARK_WARNING)
    end
  end

  ui.statusbar_text = issues .. ' issues found'
end

function M.run(mode)
  local rootpath = io.get_project_root(true)
  if not rootpath then rootpath = buffer.filename:match('^(.+)[/\\][^/\\]+$') end
  -- If we still have no root, abort with a clear message
  if not rootpath or rootpath == '' then
    ui.statusbar_text = 'ERROR - unable to determine project root'
    return
  end

  local linter_commands = {}
  -- stylua: ignore start
  linter_commands['cpp'] = 'clang-tidy -checks="*,-fuchsia*,-llvm*" -p '
    .. rootpath .. '/build/compile_commands.json '
    .. buffer.filename
    .. ' 2>&1'
  -- stylua: ignore end
  -- ruff check --fix --select I001
  linter_commands['python'] = 'ruff check --line-length 120 --select ALL --ignore D200,D205,D209,D212,D213,D400,D415 --output-format pylint '
    .. buffer.filename
    .. (_G.WIN32 and ' 2>&1' or '')
  linter_commands['lua'] = 'luacheck --no-color ' .. buffer.filename
  linter_commands['rust'] = 'cargo clippy --message-format short 2>&1'

  local build_commands = {}
  build_commands['cpp'] = 'ninja -C ' .. rootpath .. '/build'
  build_commands['rust'] = 'cargo build --message-format short 2>&1'

  local modes = {}
  modes['lint'] = linter_commands
  modes['build'] = build_commands

  local lang = buffer:get_lexer(true)
  if lang == nil or modes[mode][lang] == nil then
    ui.statusbar_text = 'no command for: ' .. lang
    return
  end

  run_and_mark(modes[mode][lang], rootpath)
end

function M.next_issue(next)
  local pos = buffer:line_from_position(buffer.current_pos)
  local get_line = next and buffer.marker_next or buffer.marker_previous
  local line = get_line(pos + (next and 1 or -1), 1 << (textadept.run.MARK_WARNING - 1))
  buffer:goto_line(line)
  view:vertical_center_caret()
end

return M
