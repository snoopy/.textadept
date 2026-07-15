-- The tagit status buffer: a read-only Textredux buffer that renders the repository status as collapsible sections
--
-- Syntax highlighting is primarily provided by the `tagit` lexer (lexers/tagit.lua):
-- structural lines get heading/keyword styling and diff lines get diff coloring.
-- File-line status codes are colored via direct Scintilla styling on `b.target`
--
-- Folding uses Scintilla's (globally configured) fold margin. Fold levels are assigned manually after each refresh;
-- the tagit lexer defines a no-op `fold` function so Scintillua's default folder never clobbers them.
-- The expanded/collapsed state is persisted in `buffer.data` so a refresh does not pop every section open.

local lfs = require('lfs')
local reduxbuffer = require('textredux.core.buffer')
local common = require('tagit.common')
local git = require('tagit.git')
local diff = require('tagit.diff')
local help = require('tagit.help')
local log = require('tagit.log')
local blame = require('tagit.blame')
local commit = require('tagit.commit')
local push = require('tagit.push')
local fetch = require('tagit.fetch')
local branch = require('tagit.branch')
local operation = require('tagit.operation')
local cherry_pick = require('tagit.cherry_pick')
local stash = require('tagit.stash')
local reset = require('tagit.reset')
local console = require('tagit.console')
-- Keys mode for diff buffers opened from the status buffer.
local STATUS_DIFF_MODE = 'tagit_status_diff'
keys[STATUS_DIFF_MODE] = setmetatable({
  q = function()
    buffer:close(true)
  end,
  esc = function()
    buffer:close(true)
  end,
  o = function()
    diff.visit_file()
  end,
}, { __index = keys })

local function update_diff_keys_mode()
  if buffer._tagit_status_diff then
    keys.mode = STATUS_DIFF_MODE
  elseif keys.mode == STATUS_DIFF_MODE then
    keys.mode = nil
  end
end
events.connect(events.BUFFER_AFTER_SWITCH, update_diff_keys_mode)
events.connect(events.VIEW_AFTER_SWITCH, update_diff_keys_mode)

local M = {}

-- Maximum number of files to render per section in the status buffer.
-- When exceeded, the list is truncated with a note. Keeps the buffer responsive
-- in large repositories.
local MAX_DISPLAY_FILES = 200

-- Relative fold depths (added to FOLDLEVELBASE).
local L_SECTION = 0
local L_CHILD = 1
local L_HUNK = 2
local L_HUNK_BODY = 3

-- Forward declaration; defined after the buffer instance exists.
local refresh

-- The singleton status buffer.
local buf = reduxbuffer.new('*tagit: status*')
buf.data = {}

-- Switch the target buffer to the tagit lexer.
-- Textadept already provides the fold margin, marker shapes and click-to-fold globally on every view, so no margin setup is needed.
-- The tagit lexer defines no fold points, so Textadept's folder returns nothing and never disturbs the fold levels we assign manually.
local function setup_buffer()
  pcall(function()
    if buffer.lexer_language ~= 'tagit' then buffer:set_lexer('tagit') end
  end)
end

-- Append a single logical line and associate metadata with it.
-- Text is inserted without a Textredux style (the `tagit` lexer colors it);
-- `command`, when given, makes the line a selectable hotspot.
-- `text` must not contain embedded newlines; the newline is added here.
local function line(b, text, meta, command)
  local before = b.line_count
  b:append_text(text .. '\n', nil, command)
  local after = b.line_count
  local lnum = after - 1
  if meta then b.data.lines[lnum] = meta end
  return lnum
end

-- Open the file referenced by a status entry in a normal buffer.
local function visit_file(entry)
  if not entry or not entry.path then return end
  local root = buf.data.root:gsub('[/\\]+$', '')
  io.open_file(root .. '/' .. entry.path)
end

-- Pick a Scintilla style name for a 2-character status code.
-- Returns a tag-name string (e.g. "keyword") that the theme has colored.
-- The numeric style slot is resolved later via buffer:style_of_name().
local function status_style_name(code)
  if code == '??' then return 'comment' end
  if code:match('^%S%S$') then return 'constant' end
  if code:match('^%S $') then return 'string' end
  if code:match('^ %S$') then return 'keyword' end
end

-- Add a file status line with a colored status-code portion.
-- Styling is deferred to pending_styles and applied in a second pass
-- after the tagit lexer runs (in on_refresh), so the lexer cannot overwrite it.
local pending_styles = {} -- reused across renders
local function status_line(b, short, path, meta, command)
  local start = b.target.length + 1
  local before = b.line_count
  b:append_text(short .. ' ' .. path .. '\n', nil, command)
  local after = b.line_count
  local lnum = after - 1
  local name = short and status_style_name(short)
  if name then pending_styles[#pending_styles + 1] = { start, #short, name } end
  if meta then b.data.lines[lnum] = meta end
  return lnum
end

-- Render the diff hunks for a file as fold children. Returns true when hunks were rendered (i.e. the file is foldable).
local function render_hunks(b, file, section, diff_text)
  local text = diff_text or git.file_diff(file.path, section == 'staged', b.data.root)
  local parsed = diff.parse(text)
  if not parsed then return false end
  for _, hunk in ipairs(parsed.hunks) do
    local meta = {
      kind = 'hunk',
      section = section,
      path = file.path,
      header = parsed.header,
      hunk = hunk,
    }
    local hunk_meta = setmetatable({ level = L_HUNK, fold_header = true }, { __index = meta })
    line(b, hunk.lines[1], hunk_meta)
    for i = 2, #hunk.lines do
      line(b, hunk.lines[i], setmetatable({ level = L_HUNK_BODY }, { __index = meta }))
    end
  end
  return true
end

-- Render a section of changed files (staged/unstaged) with their hunks.
local function render_file_section(b, title, id, files, section, diffs)
  if #files == 0 then return end
  line(b, title .. ' (' .. #files .. ')', {
    kind = 'section',
    id = id,
    section = section,
    level = L_SECTION,
    fold_header = true,
    fold_id = 'section:' .. id,
    fold_default = 'expanded',
  })
  for i, file in ipairs(files) do
    local short = (section == 'staged' and file.status or ' ') .. (section == 'unstaged' and file.status or ' ')
    local display_path = file.path
    if file.orig then display_path = file.orig .. ' -> ' .. file.path end
    local meta = {
      kind = 'file',
      section = section,
      path = file.path,
      status = file.status,
      level = L_CHILD,
      fold_id = 'file:' .. section .. ':' .. file.path,
      fold_default = 'collapsed',
    }
    local lnum = status_line(b, short, display_path, meta, visit_file)
    local has_hunks = render_hunks(b, file, section, diffs and diffs[file.path])
    meta.fold_header = has_hunks
    b.data.lines[lnum] = meta
    -- Non-header separator at L_CHILD level terminates the file-level fold
    -- so consecutive file folds do not merge (Scintilla's "not a fold header" rule).
    if i < #files then line(b, '', { level = L_CHILD }) end
  end
  line(b, '', { level = L_SECTION })
end

-- Render a simple list section (files, untracked).
local function render_list_section(b, title, id, files, section)
  if #files == 0 then return end
  line(b, title .. ' (' .. #files .. ')', {
    kind = 'section',
    id = id,
    section = section,
    level = L_SECTION,
    fold_header = true,
    fold_id = 'section:' .. id,
    fold_default = 'expanded',
  })
  for _, file in ipairs(files) do
    local short = section == 'files' and file.status or (section == 'untracked' and '??' or 'UU')
    local path = (file.orig and (file.orig .. ' -> ') or '') .. file.path
    status_line(b, short, path, {
      kind = 'file',
      section = section,
      path = file.path,
      status = file.status,
      orig = file.orig,
      level = L_CHILD,
    }, visit_file)
  end
  line(b, '', { level = L_SECTION })
end

-- Render unmerged files with conflict hunks (ours/base/theirs regions).
local function render_unmerged_section(b, files)
  if #files == 0 then return end
  line(b, 'Unmerged (' .. #files .. ')', {
    kind = 'section',
    id = 'unmerged',
    section = 'unmerged',
    level = L_SECTION,
    fold_header = true,
    fold_id = 'section:unmerged',
    fold_default = 'expanded',
  })
  for i, file in ipairs(files) do
    local meta = {
      kind = 'file',
      section = 'unmerged',
      path = file.path,
      status = 'U',
      level = L_CHILD,
      fold_id = 'file:unmerged:' .. file.path,
      fold_default = 'collapsed',
    }
    local lnum
    if b.data.root then
      local filepath = b.data.root:gsub('[/\\]+$', '') .. '/' .. file.path
      local attr = lfs.attributes(filepath)
      if attr and attr.mode == 'file' then
        local f = io.open(filepath, 'r')
        local text = f and f:read('*a')
        if f then f:close() end
        local conflicts = text and diff.parse_conflicts(text) or {}
        if #conflicts > 0 then
          meta.fold_header = true
          lnum = status_line(b, 'UU', file.path, meta, visit_file)
          for _, c in ipairs(conflicts) do
            local cmeta = setmetatable(
              { kind = 'conflict', level = L_HUNK, fold_header = true, fold_id = false },
              { __index = meta }
            )
            line(b, c.header, cmeta)
            for _, l in ipairs(c.ours) do
              line(b, l, setmetatable({ kind = 'conflict_ours', level = L_HUNK_BODY }, { __index = meta }))
            end
            for _, l in ipairs(c.base) do
              line(b, l, setmetatable({ kind = 'conflict_base', level = L_HUNK_BODY }, { __index = meta }))
            end
            for _, l in ipairs(c.theirs) do
              line(b, l, setmetatable({ kind = 'conflict_theirs', level = L_HUNK_BODY }, { __index = meta }))
            end
          end
        else
          lnum = status_line(b, 'UU', file.path, meta, visit_file)
        end
      else
        lnum = status_line(b, 'UU', file.path, meta, visit_file)
      end
    else
      lnum = status_line(b, 'UU', file.path, meta, visit_file)
    end
    if lnum then b.data.lines[lnum] = meta end
    if i < #files then line(b, '', { level = L_CHILD }) end
  end
  line(b, '', { level = L_SECTION })
end

-- Render one commit line with per-field coloring (same intent as log.lua's styles).
local function add_commit_line(b, hash, date, rel, author, subject, refs)
  local date_text = common.fit(date or '', 16) .. '  '
  local rel_text = common.fit(rel, 13) .. ' '
  local author_text = common.fit(author, 16) .. ' '
  local refs_text = refs ~= '' and ' ' .. refs or ''
  local sha_text = hash:sub(1, 9) .. ' '

  local text = sha_text .. date_text .. rel_text .. author_text .. subject .. refs_text
  local start = b.target.length + 1
  b:append_text(text .. '\n', nil, function()
    diff.show_commit(hash, b.data.root, 'status')
  end)

  local offset = 0
  pending_styles[#pending_styles + 1] = { start + offset, #sha_text, 'class' }
  offset = offset + #sha_text
  pending_styles[#pending_styles + 1] = { start + offset, #date_text, 'comment' }
  offset = offset + #date_text
  pending_styles[#pending_styles + 1] = { start + offset, #rel_text, 'number' }
  offset = offset + #rel_text
  pending_styles[#pending_styles + 1] = { start + offset, #author_text, 'function' }
  offset = offset + #author_text + #subject
  if refs ~= '' then pending_styles[#pending_styles + 1] = { start + offset, #refs_text, 'type' } end

  local lnum = b.line_count
  b.data.lines[lnum] = { kind = 'commit', hash = hash, level = L_CHILD }
end

-- Render a "Recent commits" section before Files listing the last 5 commits.
local function render_recent_commits(b)
  local root = b.data.root
  if not root then return end
  local SEP = string.char(31)
  -- stylua: ignore start
  local fmt = 'format:%H'
    .. SEP .. '%cd'
    .. SEP .. '%cr'
    .. SEP .. '%cn'
    .. SEP .. '%s'
    .. SEP .. '%d'
  local out = git.run(
    'log --date-order --date='
    .. git.quote('format:%Y-%m-%d %H:%M')
    .. ' --pretty='
    .. git.quote(fmt)
    .. ' -n 5',
    root
  )
  -- stylua: ignore end
  if not out then return end

  line(b, 'Recent commits (5)', {
    kind = 'section',
    id = 'recent_commits',
    level = L_SECTION,
    fold_header = true,
    fold_id = 'section:recent_commits',
    fold_default = 'expanded',
  })

  for l in out:gmatch('[^\n]+') do
    if l ~= '' then
      local fields = {}
      for field in (l .. SEP):gmatch('(.-)' .. SEP) do
        fields[#fields + 1] = field
      end
      local hash = fields[1]
      if hash and hash ~= '' then
        local refs = (fields[6] or ''):gsub('^%s+', '')
        add_commit_line(b, hash, fields[2] or '', fields[3] or '', fields[4] or '', fields[5] or '', refs)
      end
    end
  end
  line(b, '', { level = L_SECTION })
end

local function render_header(b, status)
  local br = status.branch
  line(b, 'Head:     ' .. (br.head or '(detached)'))
  if br.upstream then
    local ab = ''
    if br.ahead > 0 then ab = ab .. ' ahead ' .. br.ahead end
    if br.behind > 0 then ab = ab .. ' behind ' .. br.behind end
    line(b, 'Upstream: ' .. br.upstream .. ab)
  end
  local op = buf.data.operation
  if op then
    if op.type == 'merge' then
      line(b, 'Merge:    merging ' .. (op.branch or '') .. ' into ' .. (op.head or '?'))
    elseif op.type == 'rebase' then
      local prog = (op.progress and op.total) and (op.progress .. '/' .. op.total) or ''
      line(b, 'Rebase:   replaying onto ' .. (op.branch or '?') .. (prog ~= '' and ' (' .. prog .. ')' or ''))
    elseif op.type == 'cherry-pick' then
      line(b, 'Cherry:   picking ' .. (op.subject or '') .. ' onto ' .. (op.branch or '?'))
    elseif op.type == 'revert' then
      line(b, 'Revert:   reverting ' .. (op.subject or '') .. ' on ' .. (op.branch or '?'))
    end
  end
  line(b, '')
end

-- Assign Scintilla fold levels from the per-line metadata.
local function assign_fold_levels(b)
  local BASE = b.FOLDLEVELBASE
  local HEADER = b.FOLDLEVELHEADERFLAG
  for l = 1, b.line_count do
    local meta = b.data.lines[l]
    local level = BASE
    local flags = 0
    if meta then
      level = BASE + (meta.level or 0)
      if meta.fold_header then flags = HEADER end
    end
    b.target.fold_level[l] = level | flags
  end
end

-- Apply the persisted (or default) collapsed/expanded state to every fold header line.
-- NOTE: We expand before contracting to force Scintilla to recalculate fold boundaries
-- from the current levels set by assign_fold_levels(), rather than relying on stale
-- boundaries that may have been set by Scintillua's folder during buffer:colorize().
local function apply_fold_state(b)
  local state = b.data.fold_state
  for l = 1, b.line_count do
    local meta = b.data.lines[l]
    if meta and meta.fold_header and meta.fold_id then
      local desired = state[meta.fold_id] or meta.fold_default or 'expanded'
      pcall(function()
        if desired == 'collapsed' then
          view:fold_line(l, view.FOLDACTION_EXPAND)
          view:fold_line(l, view.FOLDACTION_CONTRACT)
        else
          view:fold_line(l, view.FOLDACTION_EXPAND)
        end
      end)
    end
  end
end

-- The Textredux refresh handler: rebuilds the entire buffer.
buf.on_refresh = function(b)
  -- The lexer and view-level fold display can only be configured when the target buffer is the one shown in the active view.
  -- When refreshed in the background (e.g. from an async push callback) we skip it; Textredux re-refreshes on switch.
  local is_current = b.target == buffer
  if is_current then setup_buffer() end
  b.data.lines = {}
  b.data.fold_state = b.data.fold_state or {}
  local root = common.root(b.origin_buffer and b.origin_buffer.filename)
  b.data.root = root
  if not root then
    line(b, 'Not in a git repository.')
    return
  end

  local status, err = git.status(root)
  if not status then
    line(b, 'git error: ' .. tostring(err))
    return
  end
  b.data.status = status

  b.data.operation = git.operation(root)
  pending_styles = {}

  local function truncate(items)
    if #items > MAX_DISPLAY_FILES then
      items[MAX_DISPLAY_FILES + 1] = { path = '[+ ' .. (#items - MAX_DISPLAY_FILES) .. ' more files]' }
    end
    return items
  end

  render_header(b, status)
  render_recent_commits(b)
  local tracked_files = {}
  for _, f in ipairs(status.files) do
    if f.status ~= '??' then tracked_files[#tracked_files + 1] = f end
  end
  render_list_section(b, 'Files', 'files', truncate(tracked_files), 'files')
  render_list_section(b, 'Untracked', 'untracked', truncate(status.untracked), 'untracked')
  render_unmerged_section(b, status.unmerged)
  local unstaged_diffs = git.file_diffs(false, root)
  local staged_diffs = git.file_diffs(true, root)
  render_file_section(b, 'Unstaged changes', 'unstaged', truncate(status.unstaged), 'unstaged', unstaged_diffs)
  render_file_section(b, 'Staged changes', 'staged', truncate(status.staged), 'staged', staged_diffs)

  line(b, '')
  line(b, 'Press ? for keybindings', { kind = 'hint' })

  -- Force a re-colorize so the tagit lexer styles diff lines and structural headings.
  -- Then apply status-code colors that the lexer leaves alone.
  -- NOTE: colorize must happen BEFORE fold level assignment; the lexer's no-op
  -- fold function prevents the default folder from resetting our levels.
  if is_current then
    view:set_styles()
    pcall(function()
      buffer:colorize(1, -1)
    end)
  end

  assign_fold_levels(b)
  if is_current then apply_fold_state(b) end

  -- Apply status-code styles, then restore end_styled to the full buffer
  -- length so STYLE_NEEDED does not fire for the range after the last
  -- styled position.
  if is_current then
    for _, s in ipairs(pending_styles) do
      b.target:start_styling(s[1], 0xff)
      b.target:set_styling(s[2], b.target:style_of_name(s[3]))
    end
    -- Re-style the last byte with its own style to advance end_styled.
    local last = b.target.length
    b.target:start_styling(last, 0xff)
    b.target:set_styling(1, b.target.style_at[last])
  end

  -- Restore the caret to (approximately) the previously focused line, or the top of the buffer on first open.
  local want = b.data.want_line or 1
  want = math.max(1, math.min(want, b.line_count))
  b:goto_line(want)
  b:vc_home()
end

---
-- Refreshes the status buffer while preserving the focused line.
refresh = function()
  if not buf:is_attached() then return end
  buf.data.want_line = buf:line_from_position(buf.current_pos)
  buf:refresh()
end
M.refresh = refresh

-- Remember the caret line whenever leaving the status buffer, so it is restored when returning
-- e.g. after visiting a file and switching back, which triggers a Textredux rebuild that would otherwise reset the caret.
events.connect(events.BUFFER_BEFORE_SWITCH, function()
  if buf:is_active() then buf.data.want_line = buf:line_from_position(buf.current_pos) end
end)

-- Returns the metadata entry under the caret, or nil.
local function entry_at_point()
  return buf.data.lines[buf:line_from_position(buf.current_pos)]
end

-- Find the nearest fold-header line at or above `start_line`.
local function header_line_above(start_line)
  for l = start_line, 1, -1 do
    local meta = buf.data.lines[l]
    if meta and meta.fold_header then return l, meta end
  end
end

-- Toggle the fold under the caret and remember the new state.
local function toggle_fold()
  local cur = buf:line_from_position(buf.current_pos)
  local hline, meta = header_line_above(cur)
  if not hline then return end
  pcall(function()
    view:toggle_fold(hline)
  end)
  if meta.fold_id then buf.data.fold_state[meta.fold_id] = view.fold_expanded[hline] and 'expanded' or 'collapsed' end
end

-- Expand all file-level folds, revealing their child hunks.
local function expand_all_hunks()
  for l = 1, buf.line_count do
    local meta = buf.data.lines[l]
    if meta and meta.fold_header and meta.level == L_CHILD and meta.fold_id then
      buf.data.fold_state[meta.fold_id] = 'expanded'
      pcall(function()
        view:fold_line(l, view.FOLDACTION_EXPAND)
      end)
    end
  end
end

-- Collapse all file-level folds, hiding their child hunks.
local function collapse_all_hunks()
  for l = 1, buf.line_count do
    local meta = buf.data.lines[l]
    if meta and meta.fold_header and meta.level == L_CHILD and meta.fold_id then
      buf.data.fold_state[meta.fold_id] = 'collapsed'
      pcall(function()
        view:fold_line(l, view.FOLDACTION_CONTRACT)
      end)
    end
  end
end

-- Stage the thing under the caret.
local function stage()
  local entry = entry_at_point()
  if not entry then return end
  if entry.kind == 'section' then
    if entry.id == 'unstaged' then
      common.report_git(git.stage_updated(buf.data.root))
    elseif entry.id == 'untracked' then
      for _, f in ipairs(buf.data.status.untracked) do
        common.report_git(git.stage(f.path, buf.data.root))
      end
    end
  elseif entry.kind == 'file' and entry.section ~= 'staged' then
    common.report_git(git.stage(entry.path, buf.data.root))
  elseif entry.kind == 'hunk' and entry.section == 'unstaged' then
    common.report_git(diff.stage_hunk(entry.header, entry.hunk, buf.data.root))
  else
    return
  end
  refresh()
end

-- Stage all changes in the repository.
local function stage_all()
  common.report_git(git.stage_all(buf.data.root))
  refresh()
end

-- Unstage all changes in the repository.
local function unstage_all()
  common.report_git(git.unstage_all(buf.data.root))
  refresh()
end

-- Unstage the thing under the caret.
local function unstage()
  local entry = entry_at_point()
  if not entry then return end
  if entry.kind == 'section' and entry.id == 'staged' then
    common.report_git(git.unstage_all(buf.data.root))
  elseif entry.kind == 'file' and entry.section == 'staged' then
    common.report_git(git.unstage(entry.path, buf.data.root))
  elseif entry.kind == 'file' and entry.section == 'files' and entry.status and entry.status:sub(1, 1) ~= ' ' then
    common.report_git(git.unstage(entry.path, buf.data.root))
  elseif entry.kind == 'hunk' and entry.section == 'staged' then
    common.report_git(diff.unstage_hunk(entry.header, entry.hunk, buf.data.root))
  else
    return
  end
  refresh()
end

-- Discard the working-tree change under the caret (with confirmation).
local function discard()
  local entry = entry_at_point()
  if not entry then return end
  local function confirm(text)
    return common.confirm('Discard?', text, 'Discard')
  end
  if entry.kind == 'file' and (entry.section == 'untracked' or (entry.section == 'files' and entry.status == '??')) then
    if confirm('Delete untracked file ' .. entry.path .. '?') then
      common.report_git(git.remove_untracked(entry.path, buf.data.root))
    end
  elseif entry.kind == 'file' and entry.section == 'unstaged' then
    if confirm('Discard changes in ' .. entry.path .. '?') then
      common.report_git(git.checkout_file(entry.path, buf.data.root))
    end
  elseif
    entry.kind == 'file'
    and entry.section == 'files'
    and entry.status
    and entry.status:sub(2, 2) ~= ' '
    and entry.status ~= '??'
  then
    if confirm('Discard changes in ' .. entry.path .. '?') then
      common.report_git(git.checkout_file(entry.path, buf.data.root))
    end
  elseif entry.kind == 'hunk' and entry.section == 'unstaged' then
    if confirm('Discard hunk?') then common.report_git(diff.discard_hunk(entry.header, entry.hunk, buf.data.root)) end
  else
    return
  end
  refresh()
end

-- Use ours for an unmerged file.
local function use_ours()
  local entry = entry_at_point()
  if not entry or entry.section ~= 'unmerged' then return end
  common.report_git(git.checkout_ours(entry.path, buf.data.root))
  local _, sc = git.stage(entry.path, buf.data.root)
  if sc == 0 then ui.statusbar_text = 'Resolved ' .. entry.path .. ' using ours' end
  refresh()
end

-- Use theirs for an unmerged file.
local function use_theirs()
  local entry = entry_at_point()
  if not entry or entry.section ~= 'unmerged' then return end
  common.report_git(git.checkout_theirs(entry.path, buf.data.root))
  local _, sc = git.stage(entry.path, buf.data.root)
  if sc == 0 then ui.statusbar_text = 'Resolved ' .. entry.path .. ' using theirs' end
  refresh()
end

-- Jump to previous/next unmerged file line.
local function next_unmerged(dir)
  local current = buf:line_from_position(buf.current_pos)
  local lines = buf.data.lines
  local step = dir or 1
  local start = current + step
  for l = start, step > 0 and #lines or 1, step do
    local meta = lines[l]
    if meta and meta.kind == 'file' and meta.section == 'unmerged' then
      buf:goto_line(l)
      break
    end
  end
end

local function prev_conflict()
  next_unmerged(-1)
end

local function next_conflict()
  next_unmerged(1)
end

-- Jump to previous/next section header, wrapping around.
local function next_section(dir)
  local current = buf:line_from_position(buf.current_pos)
  local lines = buf.data.lines
  local step = dir or 1
  local start = current + step
  local bound = step > 0 and #lines or 1
  for l = start, bound, step do
    local meta = lines[l]
    if meta and meta.kind == 'section' then
      buf:goto_line(l)
      return
    end
  end
  local wrap = step > 0 and 1 or #lines
  for l = wrap, (step > 0 and current - 1 or current + 1), step do
    local meta = lines[l]
    if meta and meta.kind == 'section' then
      buf:goto_line(l)
      return
    end
  end
end

local function prev_section()
  next_section(-1)
end

local function next_section_h()
  next_section(1)
end

-- Key registry. Bindings are recorded here so the `?` help overlay stays in sync with what is actually bound.
-- The init module adds the command-menu keys via M.bind too.
local keymap = {}

---
-- Binds a key on the status buffer and records it for the help overlay.
-- When `fn` is nil the binding is only recorded (for keys Textredux binds itself, such as RET and esc).
function M.bind(key, group, help_text, fn)
  if fn then buf.keys[key] = fn end
  keymap[#keymap + 1] = { key = key, group = group, help = help_text }
end

local function show_help()
  help.show('tagit status', keymap)
end

M.bind('\n', 'Navigate', 'visit') -- RET: bound by Textredux
M.bind('\t', 'Navigate', 'fold', toggle_fold)
M.bind('g', 'Navigate', 'refresh', refresh)
M.bind('q', 'Navigate', 'quit', function()
  buf:close()
end)
M.bind('esc', 'Navigate', 'quit') -- bound by Textredux
M.bind('s', 'Stage', 'stage', stage)
M.bind('u', 'Stage', 'unstage', unstage)
M.bind('A', 'Stage', 'stage all', stage_all)
M.bind('U', 'Stage', 'unstage all', unstage_all)
M.bind('d', 'Stage', 'discard', discard)
M.bind('o', 'Resolve', 'use ours', use_ours)
M.bind('t', 'Resolve', 'use theirs', use_theirs)
M.bind(',', 'Navigate', 'prev unmerged', prev_conflict)
M.bind('.', 'Navigate', 'next unmerged', next_conflict)
M.bind('_', 'Navigate', 'prev section', prev_section)
M.bind('-', 'Navigate', 'next section', next_section_h)
M.bind('end', 'Navigate', 'expand all hunks', expand_all_hunks)
M.bind('home', 'Navigate', 'collapse all hunks', collapse_all_hunks)
M.bind('?', 'Help', 'help', show_help)

M.bind('l', 'Log', 'log', function()
  log.menu()
end)

-- Blame the file under the cursor.
local function blame_file()
  local entry = entry_at_point()
  if not entry or entry.kind ~= 'file' then
    ui.statusbar_text = 'Not on a file'
    return
  end
  local root = buf.data.root
  if not root then return end
  blame.show(entry.path, root)
end
M.bind('B', 'Blame', 'blame file', blame_file)

-- Command transient menus
-- stylua: ignore start
M.bind('c', 'Commands', 'commit', commit.menu)
M.bind('p', 'Commands', 'push', push.menu)
M.bind('f', 'Commands', 'fetch', fetch.menu)
M.bind('b', 'Commands', 'branch', branch.menu)
M.bind('R', 'Commands', 'merge/rebase', operation.menu)
M.bind('C', 'Commands', 'cherry-pick', cherry_pick.menu)
M.bind('S', 'Commands', 'stash', stash.menu)
M.bind('r', 'Commands', 'reset/clean', reset.menu)
M.bind('!', 'Commands', 'git console', console.show)
-- stylua: ignore end

---
-- The status buffer instance.
M.buffer = buf

---
-- Table of action helpers (stage, unstage, discard, etc.) exposed for reuse by init menus.
M.actions = {
  stage = stage,
  unstage = unstage,
  stage_all = stage_all,
  unstage_all = unstage_all,
  discard = discard,
  toggle_fold = toggle_fold,
  expand_all_hunks = expand_all_hunks,
  collapse_all_hunks = collapse_all_hunks,
  entry_at_point = entry_at_point,
}

---
-- Shows the status buffer for the current project, refreshing its contents.
function M.show()
  buf:show()
end

return M
