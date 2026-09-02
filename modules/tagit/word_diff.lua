-- word_diff.lua -- character-level intra-line diff with word coalescing + indicator setup.
-- Uses translucent ROUNDBOX indicators colored from the default diff red/green (styles.addition/deletion).

local M = {}

M.INDIC_ADD = view.new_indic_number()
M.INDIC_DEL = view.new_indic_number()

-- Fore colors are taken from diff's default red/green (view.colors) so theme changes stay in sync.
local function setup_indicators()
  local is_terminal = UI == 'terminal'
  if is_terminal then
    view.indic_style[M.INDIC_ADD] = view.INDIC_SQUIGGLELOW
    view.indic_style[M.INDIC_DEL] = view.INDIC_SQUIGGLELOW
  else
    view.indic_style[M.INDIC_ADD] = view.INDIC_ROUNDBOX
    view.indic_style[M.INDIC_DEL] = view.INDIC_ROUNDBOX
  end
  view.indic_under[M.INDIC_ADD] = true
  view.indic_under[M.INDIC_DEL] = true
  view.indic_alpha[M.INDIC_ADD] = 48
  view.indic_alpha[M.INDIC_DEL] = 48
  view.indic_outline_alpha[M.INDIC_ADD] = 96
  view.indic_outline_alpha[M.INDIC_DEL] = 96
  -- Diff default green/red: (rgb), stored BGR via color.rgb2bgr.
  -- view.colors.green/red are BGR ints. Fallback to hard-coded BGR.
  -- Hard-coded BGR fallbacks: green 8da101 -> BGR 0x01A18D, red f85552 -> BGR 0x5255F8.
  local green = view.colors.green or view.colors.lime or 0x01A18D
  local red = view.colors.red or 0x5255F8
  view.indic_fore[M.INDIC_ADD] = green
  view.indic_fore[M.INDIC_DEL] = red
end

events.connect(events.VIEW_NEW, setup_indicators)
-- Also setup for the current view at load time (VIEW_NEW not yet fired for it).
pcall(setup_indicators)

-- Helpers --------------------------------------------------------------------

local function is_word_byte(b)
  if not b then return false end
  if b >= 48 and b <= 57 then return true end -- 0-9
  if b >= 65 and b <= 90 then return true end -- A-Z
  if b >= 97 and b <= 122 then return true end -- a-z
  if b == 95 then return true end -- _
  if b >= 128 then return true end -- multibyte/UTF-8 continuation/high
  return false
end

local function coalesce_ranges(ranges, text)
  if #ranges <= 1 then return ranges end
  local merged = { ranges[1] }
  for i = 2, #ranges do
    local prev = merged[#merged]
    local cur = ranges[i]
    local gap = cur.col - (prev.col + prev.len)
    if gap == 1 then
      local gap_byte = text:byte(prev.col + prev.len)
      if gap_byte and is_word_byte(gap_byte) then
        -- extend prev to cover gap + cur
        prev.len = cur.col + cur.len - prev.col
      else
        merged[#merged + 1] = cur
      end
    else
      merged[#merged + 1] = cur
    end
  end
  return merged
end

-- Char-level LCS -> per-line ranges (1-based col in stripped line, byte length)
local function char_diff_ranges(a, b)
  local n = #a
  local m = #b
  if n == 0 or m == 0 or a == b then return {}, {} end
  -- performance cap already checked by caller, but double-guard
  if n > 800 or m > 800 or n * m > 200000 then return {}, {} end

  -- DP matrix
  local dp = {}
  for i = 0, n do
    dp[i] = {}
    dp[i][0] = 0
  end
  for j = 0, m do
    dp[0][j] = 0
  end
  for i = 1, n do
    local a_byte = a:byte(i)
    local row = dp[i]
    local prev_row = dp[i - 1]
    for j = 1, m do
      if a_byte == b:byte(j) then
        row[j] = prev_row[j - 1] + 1
      else
        local v1 = prev_row[j]
        local v2 = row[j - 1] or 0
        row[j] = v1 >= v2 and v1 or v2
      end
    end
  end

  -- backtrack into reverse ops
  local ops = {}
  local i = n
  local j = m
  while i > 0 or j > 0 do
    if i > 0 and j > 0 and a:byte(i) == b:byte(j) then
      ops[#ops + 1] = { type = 'equal', a_pos = i, b_pos = j }
      i = i - 1
      j = j - 1
    elseif j > 0 and (i == 0 or dp[i][j - 1] >= dp[i - 1][j]) then
      ops[#ops + 1] = { type = 'add', b_pos = j }
      j = j - 1
    else
      ops[#ops + 1] = { type = 'del', a_pos = i }
      i = i - 1
    end
  end
  -- reverse to forward
  local fwd = {}
  for k = #ops, 1, -1 do
    fwd[#fwd + 1] = ops[k]
  end

  -- collect contiguous runs
  local del_ranges = {}
  local add_ranges = {}
  local k = 1
  while k <= #fwd do
    local op = fwd[k]
    if op.type == 'del' then
      local start = op.a_pos
      local len = 1
      k = k + 1
      while k <= #fwd and fwd[k].type == 'del' and fwd[k].a_pos == start + len do
        len = len + 1
        k = k + 1
      end
      del_ranges[#del_ranges + 1] = { col = start, len = len }
    elseif op.type == 'add' then
      local start = op.b_pos
      local len = 1
      k = k + 1
      while k <= #fwd and fwd[k].type == 'add' and fwd[k].b_pos == start + len do
        len = len + 1
        k = k + 1
      end
      add_ranges[#add_ranges + 1] = { col = start, len = len }
    else
      k = k + 1
    end
  end

  del_ranges = coalesce_ranges(del_ranges, a)
  add_ranges = coalesce_ranges(add_ranges, b)
  return del_ranges, add_ranges
end

M.char_diff_ranges = char_diff_ranges

-- For a contiguous -/+ block within a hunk/stash/commit: del_lines/add_lines are arrays of stripped content.
-- Returns del_map/add_map indexed by 1..pair_cnt -> range list.
function M.ranges_for_block(del_lines, add_lines)
  local del_map = {}
  local add_map = {}
  local pair_cnt = math.min(#del_lines, #add_lines)
  if pair_cnt == 0 then return del_map, add_map end
  -- performance: skip huge blocks
  if #del_lines > 50 or #add_lines > 50 then return del_map, add_map end
  for idx = 1, pair_cnt do
    local a = del_lines[idx]
    local b = add_lines[idx]
    if a ~= b and #a > 0 and #b > 0 then
      if #a <= 800 and #b <= 800 and #a * #b <= 200000 then
        local dr, ar = char_diff_ranges(a, b)
        if dr and #dr > 0 then del_map[idx] = dr end
        if ar and #ar > 0 then add_map[idx] = ar end
      end
    end
  end
  return del_map, add_map
end

-- Plain Scintilla buffer highlighting (commit diff, stash diff). Works on any buffer with diff lexer.
-- Uses cumulative offset (1-based, like status.lua) to avoid position_from_line ambiguity.
function M.highlight_plain_buffer(buf)
  buf = buf or buffer
  local len = buf.length
  if len == 0 then return end
  if len > 500 * 1024 then return end -- bound
  -- clear
  buf.indicator_current = M.INDIC_ADD
  buf:indicator_clear_range(1, len)
  buf.indicator_current = M.INDIC_DEL
  buf:indicator_clear_range(1, len)

  local line_count = buf.line_count
  local total_hunks = 0
  local del_lines = {}
  local add_lines = {}
  local del_starts = {} -- parallel byte start pos (1-based) for each del line
  local add_starts = {}
  local in_hunk = false
  local offset = 0

  local function flush_block()
    if #del_lines == 0 and #add_lines == 0 then return false end
    if total_hunks > 500 then return true end
    local del_map, add_map = M.ranges_for_block(del_lines, add_lines)
    local pair_cnt = math.min(#del_lines, #add_lines)
    for idx = 1, pair_cnt do
      local d_ranges = del_map[idx]
      local a_ranges = add_map[idx]
      local del_start = del_starts[idx]
      local add_start = add_starts[idx]
      if d_ranges and del_start then
        for _, r in ipairs(d_ranges) do
          local pos = del_start + 1 + r.col - 1 -- +1 skip leading -/+
          buf.indicator_current = M.INDIC_DEL
          buf:indicator_fill_range(pos, r.len)
        end
      end
      if a_ranges and add_start then
        for _, r in ipairs(a_ranges) do
          local pos = add_start + 1 + r.col - 1
          buf.indicator_current = M.INDIC_ADD
          buf:indicator_fill_range(pos, r.len)
        end
      end
    end
    del_lines = {}
    add_lines = {}
    del_starts = {}
    add_starts = {}
    total_hunks = total_hunks + 1
    return total_hunks > 500
  end

  for l = 1, line_count do
    local line = buf:get_line(l)
    if not line then break end
    local line_len = #line
    local raw = line:gsub('\r?\n$', '')
    local start_pos = offset + 1 -- 1-based
    if raw:match('^@@ ') then
      if flush_block() then break end
      in_hunk = true
    elseif raw:match('^diff %-%-git ') then
      if flush_block() then break end
      in_hunk = false
    elseif in_hunk then
      local first = raw:sub(1, 1)
      if first == ' ' then
        if flush_block() then break end
      elseif first == '-' and not raw:match('^%-%-%- ') then
        local content = raw:sub(2)
        del_lines[#del_lines + 1] = content
        del_starts[#del_starts + 1] = start_pos
      elseif first == '+' and not raw:match('^%+%+%+ ') then
        local content = raw:sub(2)
        add_lines[#add_lines + 1] = content
        add_starts[#add_starts + 1] = start_pos
      elseif first == '\\' then
        -- "\ No newline at end of file" - ignore
      else
        if flush_block() then break end
      end
    end
    offset = offset + line_len
  end
  flush_block()
end

-- Helper for status.lua Textredux buffers: clear pending indicators (call at start of on_refresh)
function M.clear_status_buffer(buf)
  -- buf is Textredux wrapper; target holds the real buffer
  local tgt = buf.target
  if not tgt then return end
  local len = tgt.length
  if len == 0 then return end
  tgt.indicator_current = M.INDIC_ADD
  tgt:indicator_clear_range(1, len)
  tgt.indicator_current = M.INDIC_DEL
  tgt:indicator_clear_range(1, len)
end

return M
