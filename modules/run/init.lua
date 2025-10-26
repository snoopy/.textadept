local M = {}

local function get_project_root()
  local rootpath = io.get_project_root(true)
  if not rootpath then
    ui.statusbar_text = 'Not a project'
    return nil
  end
  return rootpath
end

local function run_and_mark(cmd, cwd)
  local stdout = os.spawn(cmd, cwd):read('a')
  local issues = 0
  buffer:marker_delete_all(textadept.run.MARK_WARNING)
  buffer:eol_annotation_clear_all()

  for line in stdout:gmatch('[^\r\n]+') do
    local filepath, line_num, msg = line:match('^%s*(.-):(%d+)(.+)$')
    if not filepath or not line_num or not msg then goto continue end

    io.open_file(lfs.abspath(filepath, cwd))
    buffer:goto_line(line_num)
    issues = issues + 1
    buffer.eol_annotation_text[line_num] = msg
    buffer.eol_annotation_style[line_num] = buffer:style_of_name(lexer.EMBEDDED)
    buffer:marker_add(line_num, textadept.run.MARK_WARNING)

    ::continue::
  end
  ui.statusbar_text = issues .. ' issues found'
end

function M.run(mode)
  local rootpath = get_project_root()
  if not rootpath then return end

  local linter_commands = {}
  linter_commands['cpp'] = 'clang-tidy -checks=*,-fuchsia*,-llvm* -p '
    .. rootpath
    .. '/build/compile_commands.json '
    .. buffer.filename
  linter_commands['python'] = 'pylint --max-line-length=120 ' .. buffer.filename
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
  local line = get_line(pos + (next and 1 or -1), 1 << textadept.run.MARK_WARNING - 1)
  buffer:goto_line(line)
end

return M
