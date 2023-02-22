local M = {}

local reduxlist = require 'textredux.core.list'
local reduxstyle = require 'textredux.core.style'

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
    ui.statusbar_text = "CTAGS: No more history."
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
  if #tags == 0 then
    ui.statusbar_text = "CTAGS: No results."
    return
  end

  local list = reduxlist.new(title)
  list.column_styles = {
    reduxstyle['string'],
    reduxstyle.keyword,
    reduxstyle.default,
    reduxstyle.comment,
    reduxstyle.number,
  }
  list.headers = {'File', 'Type', 'Snippet', 'Path', 'Line'}
  list.items = tags
  list.on_selection = on_selection
  list:show()
end

local function lookup_id(id)
  local lookup_table = {}
  lookup_table['c'] = "Class"
  lookup_table['d'] = "Macro"
  lookup_table['e'] = "Enumerators"
  lookup_table['f'] = "Function"
  lookup_table['g'] = "Enumeration"
  lookup_table['l'] = "Local"
  lookup_table['m'] = "Member"
  lookup_table['n'] = "Namespace"
  lookup_table['p'] = "Prototype"
  lookup_table['s'] = "Struct"
  lookup_table['t'] = "Typedef"
  lookup_table['u'] = "Union"
  lookup_table['v'] = "Variable"
  lookup_table['x'] = "External"
  if lookup_table[id] then
    return lookup_table[id]
  end
  return id
end

-- Determine the tag files to search in.
local function find_tag_files()
  local tag_files = {}
  -- current directory's tags
  local tag_file = ((buffer.filename or ''):match('^.+[/\\]') or lfs.currentdir() .. '/') .. 'tags'
  if lfs.attributes(tag_file) then tag_files[#tag_files + 1] = tag_file end
  if buffer.filename then
    local root = io.get_project_root(buffer.filename, true)
    if root then
      -- project's tags
      tag_file = root .. '/tags'
      if lfs.attributes(tag_file) then tag_files[#tag_files + 1] = tag_file end
      -- project's specified tags
      tag_file = M[root]
      if type(tag_file) == 'string' then
        tag_files[#tag_files + 1] = tag_file
      elseif type(tag_file) == 'table' then
        for i = 1, #tag_file do tag_files[#tag_files + 1] = tag_file[i] end
      end
    end
  end

  -- global tags
  for i = 1, #M do
    tag_files[#tag_files + 1] = M[i]
  end

  return tag_files
end

local function search_in_files(pattern, function_list)
  if not pattern then
    return
  end

  -- Search all tags files for matches.
  local tags = {}
  local tag_files = find_tag_files()
  for i = 1, #tag_files do
    local dir = tag_files[i]:match('^.+[/\\]')
    local tag_found = false
    local f = io.open(tag_files[i])
    if not f then
      goto next_file
    end

    for line in f:lines() do
      local tag, file_path, ex_cmd, ext_fields, linenr = line:match(pattern)
      if tag then
        if not file_path:find('^%a?:?[/\\]') then file_path = dir .. file_path end
        if ex_cmd:find('^/') then ex_cmd = ex_cmd:match('^/^%s*(.-)%s?{?%$/$') end

        if function_list then
          local buffer_fn_trim = buffer.filename:match("^(.+)%.[^/\\]+$")
          buffer_fn_trim = buffer_fn_trim:gsub("[/\\]", "/")
          local list_fn_trim = file_path:match("^(.+)%.[^/\\]+$")
          list_fn_trim = list_fn_trim:gsub("[/\\]", "/")
          -- prevent different files with the same name from being shown
          if buffer_fn_trim ~= list_fn_trim then
            goto next_line
          end
        end

        local file_name = file_path:match('/([^/]+)$')
        ex_cmd = ex_cmd:sub(1, 40)
        tags[#tags + 1] = {file_name, lookup_id(ext_fields), ex_cmd, file_path, linenr}

        if not function_list then
          tag_found = true
        end
      elseif tag_found then
        break
      end
      ::next_line::
    end

    ::next_file::
    f:close()
  end

  return tags
end

function M.function_list()
  local filename_noext = buffer.filename:match("[/\\]([^/\\]+)%.[^.]+$")

  -- only match lines containing the current buffer's name
  local tags = search_in_files('^(%S+)\t(%S*[\\/]' .. filename_noext .. '%.%S*)\t(.+);"\t([fp])\tline:(%d+).*$', true)

  result_list("Function list: " .. buffer.filename, tags)
end

function M.find_global()
  local s = buffer:word_start_position(buffer.current_pos, true)
  local e = buffer:word_end_position(buffer.current_pos, true)
  local tag = buffer:text_range(s, e)

  -- match any line containing the full tag
  local pattern = '^(' .. tag .. ')\t(%S+)\t(.+);"\t(%l)\tline:(%d+).*$'

  result_list("Go to global symbol: " .. tag, search_in_files(pattern, false))
end

function M.find_local()
  local s = buffer:word_start_position(buffer.current_pos, true)
  local e = buffer:word_end_position(buffer.current_pos, true)
  local tag = buffer:text_range(s, e)

  local filename_noext = buffer.filename:match("[/\\]([^/\\]+)%.[^.]+$")

  -- match any line containing both tag and the current buffer's name
  local pattern = '^.*(' .. tag .. ')\t(%S*' .. filename_noext  .. '%.[^.\t]*)\t(.+);"\t(%l)\tline:(%d+).*$'

  result_list("Go to local symbol: " .. tag, search_in_files(pattern, false))
end

-- Autocompleter function for ctags.
textadept.editing.autocompleters.ctags = function()
  local s = buffer:word_start_position(buffer.current_pos, true)
  local e = buffer:word_end_position(buffer.current_pos, true)
  local tag = buffer:text_range(s, e)

  -- match anything including the (partial) tag
  local tags = search_in_files('^.*('.. tag .. '%S*)\t([^\t]+)\t(.-);"\t?(.*)$', false)
  if #tags == 0 then
    ui.statusbar_text = "CTAGS: No autocompletions found."
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
  local proc = os.spawn('ctags -f ' .. rootpath .. '/tags -R --fields=+ain --extra=+fq --c++-kinds=+p --exclude="build" ' .. rootpath)
  proc:wait()
  ui.statusbar_text = 'CTAGS initialized'
end

return M
