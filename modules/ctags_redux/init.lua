local M = {}

local reduxlist = require 'textredux.core.list'

-- List of jump positions comprising a jump history.
local jump_list = {pos = 0}

function M.go_back()
  if jump_list.pos > 0 then
    io.open_file(jump_list[jump_list.pos][1])
    buffer:goto_pos(jump_list[jump_list.pos][2])
    view:vertical_center_caret()

    jump_list[jump_list.pos] = nil
    jump_list.pos = jump_list.pos - 1
  else
    ui.statusbar_text = "ctags: no more history."
  end
end

-- Close the Textredux list and jump to the selected line in the origin buffer.
local function on_selection(list, item)
  list:close()

  -- add jump list entry
  jump_list[#jump_list + 1] = {buffer.filename, buffer.current_pos}
  jump_list.pos = #jump_list

  -- Jump to the tag.
  io.open_file(item[4])
  buffer:goto_line(item[5])
  view:vertical_center_caret()
  buffer:vc_home()
end

local function result_list(title, tags)
  local list = reduxlist.new(title)
  list.headers = {'File', 'Type', 'Snippet', 'Path', 'Line'}
  list.items = tags
  list.on_selection = on_selection
  list:show()
end

local function type_lookup(type)
  local ctags_types = {}
  ctags_types['c'] = "Class"
  ctags_types['d'] = "Macro"
  ctags_types['e'] = "Enumerators"
  ctags_types['f'] = "Function"
  ctags_types['g'] = "Enumeration"
  ctags_types['l'] = "Local"
  ctags_types['m'] = "Member"
  ctags_types['n'] = "Namespace"
  ctags_types['p'] = "Prototype"
  ctags_types['s'] = "Struct"
  ctags_types['t'] = "Typedef"
  ctags_types['u'] = "Union"
  ctags_types['v'] = "Variable"
  ctags_types['x'] = "External"
  if ctags_types[type] then
    return ctags_types[type]
  end
  return type
end

local function search_in_files(pattern, function_list)
  if not pattern then return end

  local tags = {}
  local project_root = io.get_project_root(buffer.filename, true)
  if not project_root then
    ui.statusbar_text = 'ctags: not a project'
    return
  end
  local tags_path = project_root .. '/tags'
  if not lfs.attributes(tags_path) then
    M.init_ctags()
  end
  local tags_file = io.open(tags_path)
  if not tags_file then return end

  local found = false
  for line in tags_file:lines() do
    local tag, file_path, snippet, type, linenr = line:match(pattern)
    if tag then
      if not file_path:find('^%a?:?[/\\]') then
        local dir = project_root:match('^.+[/\\]')
        file_path = dir .. file_path
      end
      local file_name = file_path:match('[/\\]([^/\\]+)$')
      tags[#tags + 1] = {file_name, type_lookup(type), snippet, file_path, linenr}
      found = true
    elseif found and not function_list then
      break
    end
  end

  tags_file:close()

  if #tags == 0 then
    ui.statusbar_text = "ctags: no results."
    return nil
  end

  return tags
end

function M.function_list()
  local tag_regex = '^(.*)\t'
  local path_regex = '(' .. buffer.filename .. ')\t'
  path_regex = path_regex:gsub('%-', '%%-')
  path_regex = path_regex:gsub('\\', '/')
  local snippet_regex = '/%^%s*(.+)%$?/;"\t'
  local type_regex = buffer.lexer_language == 'python' and '([fpm])\t' or '([fp])\t'
  local line_regex = 'line:(%d+).*$'
  local pattern = tag_regex .. path_regex .. snippet_regex .. type_regex .. line_regex
  local results = search_in_files(pattern, true)
  if not results then
    ui.statusbar_text = "ctags: no results."
    return
  end
  result_list("Function list: " .. buffer.filename, results)
end

local function find()
  buffer:set_empty_selection(buffer.current_pos)
  textadept.editing.select_word()
  tag = buffer:get_sel_text()
  buffer:set_empty_selection(buffer.current_pos)
  if not tag or type(tag) ~= 'string' then return end

  local tag_regex = '^.*(' .. tag .. ')\t'
  local path_regex = '(.*)\t'
  local snippet_regex = '/%^%s*(.+)%$?/;"\t'
  local type_regex = '(%l)\t'
  local line_regex = 'line:(%d+).*$'

  local pattern = tag_regex .. path_regex .. snippet_regex .. type_regex .. line_regex
  return search_in_files(pattern, false)
end

function M.find_global()
  tags = find()
  if not tags then return end
  result_list("CTAGS results", tags)
end

function M.function_hint()
  buffer:annotation_clear_all()
  local hint = ''
  local results = find()
  if not tags then return end
  buffer.annotation_text[buffer:line_from_position(buffer.current_pos)] = results[1][3]
  buffer:char_right()
end

-- Autocompleter function for ctags.
textadept.editing.autocompleters.ctags = function()
  local s = buffer:word_start_position(buffer.current_pos, true)
  local e = buffer:word_end_position(buffer.current_pos, true)
  local tag = buffer:text_range(s, e)

  -- match anything including the (partial) tag
  local tags = search_in_files('^.*('.. tag .. '%S*)\t([^\t]+)\t(.-);"\t?(.*)$', false)
  if #tags == 0 then
    ui.statusbar_text = "ctags: No autocompletions found."
    return
  end

  local exists = {}
  local completions = {}

  -- remove dupes
  for i = 1, #tags do
    local value = tags[i][4]
    if (not exists[value]) then
      completions[#completions + 1] = value
      exists[value] = true
    end
  end

  return e - s, completions
end

function M.init_ctags()
  local rootpath = io.get_project_root(buffer.filename, true)
  if not rootpath then
    ui.statusbar_text = 'ctags: not a project'
    return
  end
  local ctags_options = ' -R --exclude=".git" --exclude="build" --exclude="extern*" --fields=+ain  --c++-kinds=+p '
  local proc = os.spawn('ctags -f ' .. rootpath .. '/tags' .. ctags_options .. rootpath):wait()
  if proc == nil then
    ui.statusbar_text = 'ctags: init failed'
    return
  else
    ui.statusbar_text = 'ctags: initialized'
  end
end

return M
