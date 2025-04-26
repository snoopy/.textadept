local M = {}

local function get_project_root()
  local rootpath = io.get_project_root(true)
  if not rootpath then
    ui.statusbar_text = 'Not a project'
    return nil
  end
  return rootpath
end

local function exec(cmd)
  local proc = assert(io.popen(cmd, 'r'))
  local stdout = assert(proc:read('*a'))
  local issues = 0
  local build_state = true
  buffer:marker_delete_all(textadept.run.MARK_ERROR)
  buffer:marker_delete_all(textadept.run.MARK_WARNING)
  buffer:annotation_clear_all()
  for str in stdout:gmatch('[^\r\n]+') do
    local name, line, type, msg = str:match('^(.+):(%d+):%d+: (.+):(.+)$')

    if not name
        or not line
        or not type
        or not msg
        then
      goto continue
    end

    io.open_file(name)
    buffer:goto_line(line)
    issues = issues + 1
    buffer.annotation_text[line] = msg
    buffer.annotation_style[line] = buffer:style_of_name(lexer.EMBEDDED)
    buffer:marker_add(line, (type == 'error') and textadept.run.MARK_ERROR or textadept.run.MARK_WARNING)

    if type == 'error' then
      build_state = false
      break
    end

    ::continue::
  end
  proc:close()
  ui.statusbar_text = (build_state and 'Build successful: ' or 'Build failed: ') .. issues .. ' issues found'
end

function M.run(mode)
  rootpath = get_project_root()
  if not rootpath then return end

  local linter_commands = {}
  linter_commands['cpp'] = 'clang-tidy -checks=*,-fuchsia*,-llvm* -p ' .. rootpath .. '/build/compile_commands.json ' .. buffer.filename
  linter_commands['python'] = 'pylint --max-line-length=120 ' .. buffer.filename

  local build_commands = {}
  build_commands['cpp'] = 'ninja -C ' .. rootpath .. '/build'

  local modes = {}
  modes['lint'] = linter_commands
  modes['build'] = build_commands

  local lang = buffer:get_lexer(true)
  exec(modes[mode][lang])
end

function M.next_error(next)
  local pos = buffer:line_from_position(buffer.current_pos)
  local get_line = next and buffer.marker_next or buffer.marker_previous
  local line = get_line(pos + (next and 1 or -1), 1 << textadept.run.MARK_ERROR -1)
  buffer:goto_line(line)
end

return M
