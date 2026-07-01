-- Copyright 2007-2023 Mitchell. See LICENSE.

-- [[
---
-- Utilize Ctags with Textadept.
--
-- Install this module by copying it into your *~/.textadept/modules/* directory or Textadept's
-- *modules/* directory, and then putting the following in your *~/.textadept/init.lua*:
--
--     require('ctags')
--
-- There will be a "Search > Ctags" menu.
--
-- There are four ways to tell Textadept about *tags* files:
--
--   1. Place a *tags* file in a project's root directory. This file will be used in a tag
--     search from any of that project's source files.
--   2. Add a *tags* file or list of *tags* files to the [`ctags`]() module for a project root key.
--      This file(s) will be used in a tag search from any of that project's source files. For
--      example: `ctags['/path/to/project'] = '/path/to/tags'`.
--   3. Add a *tags* file to the [`ctags`]() module. This file will be used in any tag search. For
--      example: `ctags[#ctags + 1] = '/path/to/tags'`.
--   4. As a last resort, if no *tags* files were found, or if there is no match for a given
--      symbol, a temporary *tags* file is generated for the current file and used.
--
-- Textadept will use any and all *tags* files based on the above rules.
--
-- ### Generating Ctags
--
-- This module can also help generate Ctags files that can be read by Textadept. This is
-- typically configured per-project. For example, a C project might want to generate tags for
-- all files and subdirectories in a *src/* directory:
--
--     ctags.ctags_flags['/path/to/project'] = '-R src/'
--
-- A Lua project has a couple of options for generating tags:
--
--     -- Use ctags with some custom flags for improved Lua parsing.
--     ctags.ctags_flags['/path/to/project'] = ctags.LUA_FLAGS
--
-- Then, invoking Search > Ctags > Generate Project Tags menu item will generate the tags file.
--
-- ### Key Bindings
--
-- Windows and Linux | macOS | Terminal | Command
-- -|-|-|-
-- **Search**| | |
-- F12 | F12 | F12 | Go to Ctag
-- Shift+F12 | ⇧F12 | S-F12 | Go to Ctag...
-- @module ctags
-- ]]

local M = {}

local WIN32 = OS == 'windows'

---
-- Path to the ctags executable.
-- The default value is `'ctags'`.
M.ctags = 'ctags'

---
-- Map of project root paths to string command-line options, or functions that return such
-- strings, that are passed to ctags when generating project tags.
-- @see LUA_FLAGS
M.ctags_flags = table.concat({
  '-R',
  '--exclude="extern*"',
  '--exclude="bin"',
  '--exclude="doc*"',
  '--exclude=.git',
  '--exclude=.hg',
  '--exclude=.svn',
  '--exclude=node_modules',
  '--exclude=dist ',
  '--exclude=build',
  '--exclude=coverage',
  '--exclude="*.min.*"',
  '--exclude="*.swp"',
  '--exclude="*.swo"',
  '--exclude="*.pyc"',
  '--exclude="*.class"',
  '--exclude=DB_CONFIG',
  '--exclude="*.log"',
  '--exclude="*.bak"',
  '--exclude="*.cache"',
  '--exclude="*.dll"',
  '--exclude="*.exe"',
  '--exclude="*.pdb"',
  '--exclude="*.so"',
  '--exclude="*.dylib"',
  '--exclude="*.a"',
  '--exclude="*.lib"',
  '--exclude="*.o"',
  '--exclude="*.obj"',
  '--exclude="*.gcno"',
  '--exclude="*.gcda"',
  '--exclude="third_party/*"',
  '--exclude=".*"',
}, ' ')

M.api_commands = {} -- legacy

---
-- A set of command-line options for ctags that better parses Lua code.
-- Combine this with other flags in [`ctags.ctags_flags`]() if Lua files will be parsed.

M.LUA_FLAGS = table.concat({
  '--languages=Lua',
  '--fields=+iaS',
  '--extras=+fq',
  '--kinds-Lua=+f',
  '--output-format=u-ctags',
}, ' ')

M.CPP_FLAGS = table.concat({
  '--languages=C++',
  '--langmap=C++:+.h',
  '--fields=+iaS{line}{end}{kind}{scope}{signature}',
  '--extras=+fq',
  '--tag-relative=yes',
  '--kinds-C++=*',
  '--output-format=u-ctags',
}, ' ')

M.PYTHON_FLAGS = table.concat({
  '--languages=Python',
  '--langmap=Python:+.py',
  '--fields=+iaSK',
  '--extras=+fq',
  '--kinds-Python=+cfmvi',
  '--output-format=u-ctags',
}, ' ')

M.DEFAULT_FLAGS = table.concat({
  '--fields=+iaS',
  '--extras=+fq',
  '--output-format=u-ctags',
})

local LANG_FLAGS = {
  ['cpp'] = M.CPP_FLAGS,
  ['lua'] = M.LUA_FLAGS,
  ['python'] = M.PYTHON_FLAGS,
}

-- Localizations.
local _L = _L
if not rawget(_L, 'Ctags') then
  -- Dialogs.
  _L['Extra Information'] = 'Extra Information'
  _L['Go To Tag'] = 'Go To Tag'
  -- Menu.
  _L['Ctags'] = '_Ctags'
  _L['Go To Ctag'] = '_Go To Ctag'
  _L['Go To Ctag...'] = 'G_o To Ctag...'
  _L['Autocomplete Tag'] = '_Autocomplete Tag'
  _L['Generate Project Tags'] = 'Generate _Project Tags'
end

local function paths_match(a, b)
  a = a:gsub('[/\\]', '/'):gsub('/+', '/')
  b = b:gsub('[/\\]', '/'):gsub('/+', '/')
  if WIN32 then
    a, b = a:lower(), b:lower()
  end
  return a == b
end

-- Searches all available tags files tag *tag* and returns a table of tags found.
-- All Ctags in tags files must be sorted.
-- @param tag Tag to find.
-- @param filepath Optional full file path to filter results to only tags from that file.
-- @return table of tags found with each entry being a table that contains the 4 ctags fields
local function find_tags(pattern, filepath)
  -- TODO: binary search?
  local tags = {}
  -- Determine the tag files to search in.
  local tag_files = {}
  local function add_tag_file(file)
    for i = 1, #tag_files do
      if tag_files[i] == file then return end
    end
    tag_files[#tag_files + 1] = file
  end
  local root = io.get_project_root()
  if root then
    local tag_file = root .. '/tags' -- project's tags
    if lfs.attributes(tag_file) then add_tag_file(tag_file) end
    tag_file = M[root] -- project's specified tags
    if type(tag_file) == 'string' then
      add_tag_file(tag_file)
    elseif type(tag_file) == 'table' then
      for i = 1, #tag_file do
        add_tag_file(tag_file[i])
      end
    end
  end
  for i = 1, #M do
    add_tag_file(M[i])
  end -- global tags
  -- Search all tags files for matches.
  local tmpfile
  ::retry::
  for _, filename in ipairs(tag_files) do
    local dir = filename:match('^.+[/\\]')
    local f = io.open(filename)
    if not f then goto continue end
    for line in f:lines() do
      local name, file, ex_cmd, ext_fields = line:match(pattern)
      if name then
        if not file:find('^%a?:?[/\\]') then file = (dir or '') .. file end
        if ex_cmd:find('^/') then ex_cmd = ex_cmd:match('^/^?(.-)$?/$') end
        file = file:gsub('\\\\', '\\')
        if not filepath or paths_match(file, filepath) then tags[#tags + 1] = { name, file, ex_cmd, ext_fields } end
      end
    end
    f:close()
    ::continue::
  end
  if #tags == 0 and buffer.filename and not tmpfile then
    -- If no matches were found, try the current file.
    tmpfile = os.tmpname()
    if WIN32 then tmpfile = os.getenv('TEMP') .. tmpfile end
    local cmd = string.format('%s -o "%s" "%s"', M.ctags, tmpfile, buffer.filename)
    if os.spawn(cmd):wait() == 0 then
      tag_files = { tmpfile }
      goto retry
    end
  end
  if tmpfile then os.remove(tmpfile) end
  return tags
end

---
-- Jumps to the source of string *tag* or the source of the word under the caret.
-- Prompts the user when multiple sources are found.
-- @param tag The tag to go to the source of.
-- @return whether or not a tag was found and jumped to.
function M.goto_tag(tag, file_only, from_dialog, ext_filter)
  if not tag then
    local s = buffer:word_start_position(buffer.current_pos, true)
    local e = buffer:word_end_position(buffer.current_pos, true)
    tag = buffer:text_range(s, e)
  end
  if not tag or tag:match('^%s*$') and not file_only then return end

  -- Search for potential tags to go to.

  local escaped = buffer.filename:match('[^/\\]+$'):gsub('[%^%$%(%)%%%.%[%]%*%+%-%?]', '%%%1')
  local fileonly_pattern = '^([^\t]+)\t(.-' .. escaped .. ')\t(.-);"\t?(.*)$'
  local def_pattern = file_only and fileonly_pattern or '^(' .. tag .. ')\t([^\t]+)\t(.-);"\t?(.*)$'
  -- use a more lenient pattern when searching via input dialog
  local pattern = from_dialog and '^([^\t]*' .. tag .. '[^\t]*)\t([^\t]+)\t(.-);"\t?(.*)$' or def_pattern
  local tags = find_tags(pattern, file_only and buffer.filename)

  if ext_filter and #tags > 0 then
    local filtered = {}
    for _, t in ipairs(tags) do
      local ext = t[2]:match('%.([^.]*)$')
      if ext and ext_filter[ext] then filtered[#filtered + 1] = t end
    end
    tags = filtered
    if #tags == 0 then return false end
  end
  -- Prompt the user to select a tag from multiple candidates or automatically pick the only one.
  if #tags > 1 then
    local items = {}
    for _, current_tag in ipairs(tags) do
      items[#items + 1] = current_tag[1]
      items[#items + 1] = current_tag[2]:match('[^/\\]+$') -- filename only
      items[#items + 1] = current_tag[3]:match('^%s*(.+)$') -- strip indentation
      items[#items + 1] = current_tag[4]:match('^%a?%s*(.*)$') -- ignore kind
    end
    local i = ui.dialogs.list({
      title = _L['Go To Tag'],
      columns = { _L['Name'], _L['Filename'], _L['Line:'], _L['Extra Information'] },
      items = items,
      search_column = 2,
    })
    if not i then return false end
    tag = tags[i]
  else
    tag = tags[1]
  end
  if not tag or not lfs.attributes(tag[2]) then return false end
  -- Store the current position in the jump history, if applicable.
  textadept.history.record()
  -- Jump to the tag.
  io.open_file(tag[2])
  if not tonumber(tag[3]) then
    for i = 1, buffer.line_count do
      if buffer:get_line(i):find(tag[3], 1, true) then
        textadept.editing.goto_line(i)
        break
      end
    end
  else
    textadept.editing.goto_line(tonumber(tag[3]))
  end
  view:vertical_center_caret()
  -- Store the new position in the jump history.
  textadept.history.record()
  return true
end

function M.fileonly()
  M.goto_tag(nil, true, false)
end

---
-- Autocompleter function for ctags. (Names only; not context-sensitive).
-- Does not remove duplicates.
-- @function _G.textadept.editing.autocompleters.ctag
textadept.editing.autocompleters.ctag = function()
  local completions = {}
  local s = buffer:word_start_position(buffer.current_pos, true)
  local e = buffer:word_end_position(buffer.current_pos, true)
  local word = buffer:text_range(s, e):gsub('[%^%$%(%)%%%.%[%]%*%+%-%?]', '%%%1')
  local tags = find_tags('^([^\t]*' .. word .. '[^\t]*)\t([^\t]+)\t(.-);"\t?(.*)$')
  for i = 1, #tags do
    completions[#completions + 1] = tags[i][1]
  end
  return e - s, completions
end

-- Add menu entries and configure key bindings.
local m_search = textadept.menu.menubar[_L['Search']]
local SEPARATOR = { '' }
m_search[#m_search + 1] = SEPARATOR
m_search[#m_search + 1] = {
  title = _L['Ctags'], --
  { _L['Go To Ctag'], M.goto_tag },
  {
    _L['Go To Ctag...'],
    function()
      local name = ui.dialogs.input({ title = _L['Go To Tag'] })
      if name and name ~= '' then M.goto_tag(name, false, true) end
    end,
  },
  SEPARATOR, --
  {
    _L['Autocomplete Tag'],
    function()
      textadept.editing.autocomplete('ctag')
    end,
  }, --
  SEPARATOR,
  {
    _L['Generate Project Tags'],
    function()
      local root_directory = io.get_project_root()
      if not root_directory then return end

      local ctags_flags
      local lang = buffer:get_lexer(true)
      if LANG_FLAGS[lang] then
        ctags_flags = string.format('%s %s', M.ctags_flags, LANG_FLAGS[lang])
      else
        ctags_flags = string.format('%s %s', M.ctags_flags, M.DEFAULT_FLAGS)
      end

      if os.spawn(string.format('%s %s', M.ctags, ctags_flags), root_directory):wait() ~= 0 then
        ui.statusbar_text = 'Ctags not found'
      else
        ui.statusbar_text = 'Tags generated'
      end
    end,
  },
}

return M
