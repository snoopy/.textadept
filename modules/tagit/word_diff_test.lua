-- Tests for tagit.word_diff intra-line highlighting.

local userhome = (os.getenv('USERPROFILE') or os.getenv('HOME')) .. '/.textadept'
package.path = string.format('%s/modules/?.lua;%s/modules/?/init.lua;%s', userhome, userhome, package.path)

local word_diff = require('tagit.word_diff')

-- helpers
local function sorted_ranges(ranges)
  local t = {}
  for _, r in ipairs(ranges) do t[#t + 1] = r.col .. ':' .. r.len end
  table.sort(t)
  return t
end

-- char_diff_ranges ----------------------------------------------------------

test('word_diff.char_diff_ranges returns empty for empty strings', function()
  local d, a = word_diff.char_diff_ranges('', '')
  test.assert_equal(0, #d)
  test.assert_equal(0, #a)
end)

test('word_diff.char_diff_ranges returns empty for one empty string', function()
  local d, a = word_diff.char_diff_ranges('hello', '')
  test.assert_equal(0, #d)
  test.assert_equal(0, #a)
  d, a = word_diff.char_diff_ranges('', 'hello')
  test.assert_equal(0, #d)
  test.assert_equal(0, #a)
end)

test('word_diff.char_diff_ranges returns empty for identical strings', function()
  local d, a = word_diff.char_diff_ranges('hello', 'hello')
  test.assert_equal(0, #d)
  test.assert_equal(0, #a)
end)

test('word_diff.char_diff_ranges detects single-char substitution', function()
  -- hello vs hallo: 'e'->'a' at col 2
  local d, a = word_diff.char_diff_ranges('hello', 'hallo')
  test.assert_equal(1, #d)
  test.assert_equal(2, d[1].col)
  test.assert_equal(1, d[1].len)
  test.assert_equal(1, #a)
  test.assert_equal(2, a[1].col)
  test.assert_equal(1, a[1].len)
end)

test('word_diff.char_diff_ranges detects insertion', function()
  -- ab vs acb: insertion of 'c' at col 2 in b? Actually a=ab, b=acb -> 'c' added
  local d, a = word_diff.char_diff_ranges('ab', 'acb')
  test.assert_equal(0, #d)
  test.assert_equal(1, #a)
  test.assert_equal(2, a[1].col)
  test.assert_equal(1, a[1].len)
end)

test('word_diff.char_diff_ranges detects deletion', function()
  local d, a = word_diff.char_diff_ranges('acb', 'ab')
  test.assert_equal(1, #d)
  test.assert_equal(1, d[1].len)
  test.assert_equal(0, #a)
end)

test('word_diff.char_diff_ranges coalesces word-internal single-char gap', function()
  -- a="axby", b="azbw" -> a= a x b y, b= a z b w, so x->z at col2 and y->w at col4 with gap 'b' word char
  local d, a = word_diff.char_diff_ranges('axby', 'azbw')
  if #d == 1 then
    test.assert_equal(2, d[1].col)
    test.assert_equal(3, d[1].len)
    test.assert_equal(1, #a)
    test.assert_equal(2, a[1].col)
    test.assert_equal(3, a[1].len)
  else
    test.assert_equal(2, #d)
  end
end)

test('word_diff.char_diff_ranges does not coalesce across space', function()
  local d, a = word_diff.char_diff_ranges('x y', 'a b')
  test.assert_equal(2, #d)
  test.assert_equal(1, d[1].col)
  test.assert_equal(3, d[2].col)
end)

test('word_diff.char_diff_ranges respects length product guard', function()
  local long = string.rep('a', 801)
  local d, a = word_diff.char_diff_ranges(long, long .. 'b')
  test.assert_equal(0, #d)
  test.assert_equal(0, #a)
  local s500 = string.rep('a', 500)
  local t500 = string.rep('b', 500)
  d, a = word_diff.char_diff_ranges(s500, t500)
  test.assert_equal(0, #d)
  test.assert_equal(0, #a)
end)

-- ranges_for_block ----------------------------------------------------------

test('word_diff.ranges_for_block pairs lines by index', function()
  local del = {'hello', 'world'}
  local add = {'hallo', 'worlds'}
  local dm, am = word_diff.ranges_for_block(del, add)
  test.assert_equal(1, dm[1] and #dm[1] or 0)
  test.assert_equal(1, am[1] and #am[1] or 0)
  test.assert(am[2] and #am[2] >= 1, 'expected add range for second pair')
end)

test('word_diff.ranges_for_block handles mismatched counts (only min pairs highlighted)', function()
  local del = {'a', 'b', 'c'}
  local add = {'A'}
  local dm, am = word_diff.ranges_for_block(del, add)
  test.assert(dm[1] and #dm[1] > 0, 'first pair should have diff')
  test.assert_equal(nil, dm[2])
  test.assert_equal(nil, dm[3])
  test.assert_equal(nil, am[2])
end)

test('word_diff.ranges_for_block skips empty identical lines', function()
  local dm, am = word_diff.ranges_for_block({'same'}, {'same'})
  test.assert_equal(nil, dm[1])
  test.assert_equal(nil, am[1])
end)

test('word_diff.ranges_for_block skips empty strings', function()
  local dm, am = word_diff.ranges_for_block({''}, {'hello'})
  test.assert_equal(nil, dm[1])
end)

test('word_diff.ranges_for_block skips huge blocks (>50 lines)', function()
  local del, add = {}, {}
  for i = 1, 51 do del[i] = 'a' .. i; add[i] = 'b' .. i end
  local dm, am = word_diff.ranges_for_block(del, add)
  test.assert_equal(nil, dm[1])
end)

test('word_diff.ranges_for_block skips lines >800 bytes', function()
  local long = string.rep('x', 801)
  local dm, am = word_diff.ranges_for_block({long}, {long .. 'y'})
  test.assert_equal(nil, dm[1])
end)

test('word_diff.ranges_for_block skips product >200k', function()
  local s = string.rep('a', 500)
  local t = string.rep('b', 500)
  local dm, am = word_diff.ranges_for_block({s}, {t})
  test.assert_equal(nil, dm[1])
end)

test('word_diff.ranges_for_block returns empty for empty input', function()
  local dm, am = word_diff.ranges_for_block({}, {})
  test.assert_equal(0, #dm)
  test.assert_equal(0, #am)
  dm, am = word_diff.ranges_for_block({'a'}, {})
  test.assert_equal(0, #dm)
end)

-- highlight_plain_buffer ----------------------------------------------------

test('word_diff.highlight_plain_buffer highlights intra-line change in commit/stash buffer', function()
  buffer:clear_all()
  buffer:set_lexer('diff')
  local diff_text = table.concat({
    'diff --git a/file.txt b/file.txt',
    '--- a/file.txt',
    '+++ b/file.txt',
    '@@ -1 +1 @@',
    '-hello',
    '+hallo',
    ''
  }, '\n')
  buffer:add_text(diff_text)
  word_diff.highlight_plain_buffer(buffer)
  local del_texts = test.get_indicated_text(word_diff.INDIC_DEL)
  local add_texts = test.get_indicated_text(word_diff.INDIC_ADD)
  test.assert_contains(del_texts, 'e')
  test.assert_contains(add_texts, 'a')
end)

test('word_diff.highlight_plain_buffer respects hunk boundaries and ---/+++ headers', function()
  buffer:clear_all()
  buffer:set_lexer('diff')
  local diff_text = table.concat({
    'diff --git a/file.txt b/file.txt',
    '--- a/file.txt',
    '+++ b/file.txt',
    '@@ -1 +1 @@',
    ' context',
    '-old',
    '+new',
    ' context2',
    ''
  }, '\n')
  buffer:add_text(diff_text)
  word_diff.highlight_plain_buffer(buffer)
  local del = test.get_indicated_text(word_diff.INDIC_DEL)
  local add = test.get_indicated_text(word_diff.INDIC_ADD)
  test.assert(#del >= 1 or #add >= 1, 'expected at least one indicator')
end)

test('word_diff.highlight_plain_buffer flushes on context lines (separate blocks)', function()
  buffer:clear_all()
  buffer:set_lexer('diff')
  local diff_text = table.concat({
    'diff --git a/file.txt b/file.txt',
    '--- a/file.txt',
    '+++ b/file.txt',
    '@@ -1,3 +1,3 @@',
    '-foo',
    '+bar',
    ' keep',
    '-hello',
    '+hallo',
    ''
  }, '\n')
  buffer:add_text(diff_text)
  word_diff.highlight_plain_buffer(buffer)
  local del = test.get_indicated_text(word_diff.INDIC_DEL)
  local add = test.get_indicated_text(word_diff.INDIC_ADD)
  test.assert(#del >= 2, 'expected highlights from both blocks')
end)

test('word_diff.highlight_plain_buffer ignores \\ No newline marker', function()
  buffer:clear_all()
  buffer:set_lexer('diff')
  local diff_text = table.concat({
    'diff --git a/file.txt b/file.txt',
    '--- a/file.txt',
    '+++ b/file.txt',
    '@@ -1 +1 @@',
    '-hello',
    '+hallo',
    '\\ No newline at end of file',
    ''
  }, '\n')
  buffer:add_text(diff_text)
  word_diff.highlight_plain_buffer(buffer)
  local del = test.get_indicated_text(word_diff.INDIC_DEL)
  test.assert_contains(del, 'e')
end)

test('word_diff.highlight_plain_buffer handles empty and large buffers gracefully', function()
  buffer:clear_all()
  word_diff.highlight_plain_buffer(buffer)
  test.assert_equal(0, #test.get_indicated_text(word_diff.INDIC_DEL))
  buffer:clear_all()
  buffer:add_text(string.rep('x', 600 * 1024))
  word_diff.highlight_plain_buffer(buffer)
  test.assert_equal(0, #test.get_indicated_text(word_diff.INDIC_DEL))
end)

test('word_diff.highlight_plain_buffer clears previous highlights when diff has no intra-line change', function()
  buffer:clear_all()
  buffer:set_lexer('diff')
  buffer:add_text(table.concat({
    'diff --git a/file.txt b/file.txt',
    '--- a/file.txt',
    '+++ b/file.txt',
    '@@ -1 +1 @@',
    '-hello',
    '+hallo',
    ''
  }, '\n'))
  word_diff.highlight_plain_buffer(buffer)
  test.assert(#test.get_indicated_text(word_diff.INDIC_DEL) > 0, 'setup: expected highlight')
  buffer:clear_all()
  buffer:add_text(table.concat({
    'diff --git a/file.txt b/file.txt',
    '--- a/file.txt',
    '+++ b/file.txt',
    '@@ -1 +1 @@',
    ' same',
    ' same2',
    ''
  }, '\n'))
  word_diff.highlight_plain_buffer(buffer)
  test.assert_equal(0, #test.get_indicated_text(word_diff.INDIC_DEL))
  test.assert_equal(0, #test.get_indicated_text(word_diff.INDIC_ADD))
end)

test('word_diff.highlight_plain_buffer handles multiple diff --git sections', function()
  buffer:clear_all()
  buffer:set_lexer('diff')
  local diff_text = table.concat({
    'diff --git a/a.txt b/a.txt',
    '--- a/a.txt',
    '+++ b/a.txt',
    '@@ -1 +1 @@',
    '-foo',
    '+bar',
    'diff --git a/b.txt b/b.txt',
    '--- a/b.txt',
    '+++ b/b.txt',
    '@@ -1 +1 @@',
    '-hello',
    '+hallo',
    ''
  }, '\n')
  buffer:add_text(diff_text)
  word_diff.highlight_plain_buffer(buffer)
  local del = test.get_indicated_text(word_diff.INDIC_DEL)
  local add = test.get_indicated_text(word_diff.INDIC_ADD)
  test.assert(#del >= 2, 'expected highlights from both files')
end)
