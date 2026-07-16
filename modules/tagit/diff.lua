-- Unified-diff parsing and per-hunk patch application for the tagit module.
--
-- A file diff is split into a header (the `diff --git`, `index`, `---`, `+++` lines) and an ordered list of hunks.
-- A single hunk can be turned back into a self-contained patch (header + that hunk) and
-- fed to `git apply` to stage, unstage or discard just that hunk.

local git = require('tagit.git')
local common = require('tagit.common')

local M = {}

---
-- Parses unified diff text for a single file into a header and hunks.
-- @param text The full `git diff` output for one file.
-- @return a table `{ header = <string>, hunks = { { header=, lines=, text= } } }`
-- where each hunk's `text` includes its `@@` line and body, terminated by a newline.
-- Returns nil when no hunks are present (binary/empty diff).
function M.parse(text)
  if not text or text == '' then return nil end
  local lines = {}
  for line in (text .. '\n'):gmatch('(.-)\n') do
    lines[#lines + 1] = line
  end

  local header = {}
  local hunks = {}
  local current = nil
  local in_hunks = false

  for _, line in ipairs(lines) do
    if line:match('^@@ ') then
      in_hunks = true
      current = { header = line, lines = { line } }
      hunks[#hunks + 1] = current
    elseif in_hunks then
      current.lines[#current.lines + 1] = line
    else
      header[#header + 1] = line
    end
  end

  if #hunks == 0 then return nil end

  for _, hunk in ipairs(hunks) do
    hunk.text = table.concat(hunk.lines, '\n') .. '\n'
  end

  return { header = table.concat(header, '\n') .. '\n', hunks = hunks }
end

-- Build a one-hunk patch from a parsed diff header and a hunk.
local function build_patch(header, hunk)
  return header .. hunk.text
end

---
-- Stages a single hunk by applying it to the index.
-- @param header The diff header for the file.
-- @param hunk A hunk table as returned by @{M.parse}.
-- @param root Optional repository root.
-- @return (out, code) from git.run_with_input.
function M.stage_hunk(header, hunk, root)
  return git.run_with_input('apply --cached', build_patch(header, hunk), root)
end

---
-- Unstages a single hunk by reverse-applying it to the index.
-- The hunk must come from a staged diff (`git diff --cached`).
-- @param header The diff header for the file.
-- @param hunk A hunk table as returned by @{M.parse}.
-- @param root Optional repository root.
-- @return (out, code) from git.run_with_input.
function M.unstage_hunk(header, hunk, root)
  return git.run_with_input('apply --cached --reverse', build_patch(header, hunk), root)
end

---
-- Discards a single unstaged hunk by reverse-applying it to the working tree.
-- @param header The diff header for the file.
-- @param hunk A hunk table as returned by @{M.parse}.
-- @param root Optional repository root.
-- @return (out, code) from git.run_with_input.
function M.discard_hunk(header, hunk, root)
  return git.run_with_input('apply --reverse', build_patch(header, hunk), root)
end

--- Finds a conflict marker (`<<<<<<< `, `||||||| `, `=======`, `>>>>>>> `)
-- ensuring it is at the start of a line.
-- For markers without a trailing space (`=======`), also requires nothing follows on the same line.
-- Returns the position of the marker, or nil.
local function find_marker(text, marker, pos)
  local s = text:find(marker, pos)
  if not s then return nil end
  local after = s + #marker
  -- Must be at start of a line
  if s > 1 then
    local prev = text:sub(s - 1, s - 1)
    if prev ~= '\n' and prev ~= '\r' then return find_marker(text, marker, after) end
  end
  -- For markers without trailing space (=======), nothing must follow
  if marker:sub(-1) ~= ' ' then
    local ch = text:sub(after, after)
    if ch ~= '' and ch ~= '\n' and not (ch == '\r' and text:sub(after + 1, after + 1) == '\n') then
      return find_marker(text, marker, after)
    end
  end
  return s
end

local function line_end(text, pos)
  local e = text:find('[\n\r]', pos)
  return e or #text + 1
end

local function read_lines(text, from, to)
  local lines = {}
  for line in (text:sub(from, to - 1) .. '\n'):gmatch('(.-)\n') do
    lines[#lines + 1] = line
  end
  return lines
end

---
-- Parses conflict markers from a file's text content.
-- @param text The full file text.
-- @return a list of conflict regions, each with:
--   `header` "@@ -l,c +l,c @@ (conflict)" string
--   `ours` list of our-side lines (including `<<<<<<<` header)
--   `base` list of merge-base lines (including `|||||||` header, empty without diff3)
--   `theirs` list of their-side lines (including `=======` and `>>>>>>>`)
-- Returns an empty list when no conflicts are found.
function M.parse_conflicts(text)
  local conflicts = {}
  local pos = 1
  while true do
    local ours_start = find_marker(text, '<<<<<<< ', pos)
    if not ours_start then break end
    local ours_end = find_marker(text, '||||||| ', ours_start)
    local base_start, divider_start, divider_end
    local their_start, ending
    if ours_end then
      -- diff3 style: <<<<<<< ... ||||||| ... ======= ... >>>>>>>
      base_start = ours_end
      divider_start = find_marker(text, '=======', ours_end)
      if not divider_start then
        their_start = find_marker(text, '>>>>>>> ', ours_end)
        if not their_start then break end
        ending = line_end(text, their_start)
        local conflict = {
          header = '@@ (conflict)',
          ours = {},
          base = {},
          theirs = read_lines(text, ours_start, ending),
        }
        conflicts[#conflicts + 1] = conflict
        pos = ending
      else
        divider_end = line_end(text, divider_start)
        their_start = find_marker(text, '>>>>>>> ', divider_end)
        if not their_start then break end
        ending = line_end(text, their_start)
        local conflict = {
          header = '@@ (conflict)',
          ours = read_lines(text, ours_start, ours_end - 1),
          base = read_lines(text, base_start, divider_start - 1),
          theirs = read_lines(text, divider_end + 1, ending),
        }
        conflicts[#conflicts + 1] = conflict
        pos = ending
      end
    else
      -- 2-way style: <<<<<<< ... ======= ... >>>>>>>
      divider_start = find_marker(text, '=======', ours_start)
      if not divider_start then break end
      divider_end = line_end(text, divider_start)
      their_start = find_marker(text, '>>>>>>> ', divider_end)
      if not their_start then break end
      ending = line_end(text, their_start)
      local conflict = {
        header = '@@ (conflict)',
        ours = read_lines(text, ours_start, divider_start - 1),
        base = {},
        theirs = read_lines(text, divider_end + 1, ending),
      }
      conflicts[#conflicts + 1] = conflict
      pos = ending
    end
  end
  return conflicts
end

---
-- Shows a commit's diff in a new buffer with a changed-files summary header.
-- The buffer gets `_tagit_<mode_id>_diff` flag for key mode detection.
-- @param sha Commit hash to display.
-- @param root Repository root.
-- @param mode_id Short id used in buffer flags and keys mode (`'log'` or `'status'`).
function M.show_commit(sha, root, mode_id)
  if not root then return end
  local files = git.run('diff-tree --no-commit-id -c -r --name-status ' .. git.quote(sha), root)
  local out = git.run(
    'show --no-color --pretty='
      .. git.quote('format:commit: %H%na: %ad %aN%nc: %cd %cN%n%s%n%n%b%n')
      .. ' '
      .. git.quote(sha),
    root
  )
  if not out then return end
  buffer.new()
  buffer['_tagit_' .. mode_id .. '_diff'] = true
  buffer['_tagit_sha'] = sha
  buffer['_tagit_root'] = root
  buffer:set_lexer('diff')
  -- Split at the first diff line so the file list sits between commit info and the diff.
  local diff_pos = out:find('\ndiff ', 1, true)
  if diff_pos and files and files ~= '' then
    buffer:add_text(out:sub(1, diff_pos - 1))
    buffer:add_text('\nChanged files:\n')
    buffer:add_text(files)
    if files:sub(-1) ~= '\n' then buffer:add_text('\n') end
    buffer:add_text('\n')
    buffer:add_text(out:sub(diff_pos + 1))
  else
    if files and files ~= '' then
      buffer:add_text('Changed files:\n')
      buffer:add_text(files)
      if files:sub(-1) ~= '\n' then buffer:add_text('\n') end
      buffer:add_text('\n')
    end
    buffer:add_text(out)
  end
  buffer:goto_pos(1)
  buffer:set_save_point()
  buffer.read_only = true
  keys.mode = 'tagit_' .. mode_id .. '_diff'
end

--- Picks a file from the commit diff's changed files and opens it.
-- @param sha Optional commit hash (defaults to buffer._tagit_sha).
-- @param root Optional repository root (defaults to buffer._tagit_root).
function M.visit_file(sha, root)
  sha = sha or buffer._tagit_sha
  root = root or buffer._tagit_root
  if not sha or not root then
    ui.statusbar_text = 'Not a commit diff buffer'
    return
  end
  local out = git.run('diff-tree --no-commit-id -c -r --name-only ' .. git.quote(sha), root)
  if not out then return end
  local files = {}
  for f in out:gmatch('[^\n]+') do
    local trimmed = f:gsub('\r$', '')
    if trimmed ~= '' then files[#files + 1] = trimmed end
  end
  if #files == 0 then
    ui.statusbar_text = 'No files in commit'
    return
  end
  common.pick('Files in ' .. sha:sub(1, 9), files, function(file)
    if file then io.open_file(root .. '/' .. file) end
  end)
end

return M
