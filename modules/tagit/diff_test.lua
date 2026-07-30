-- Tests for tagit.diff parsers.

local userhome = (os.getenv('USERPROFILE') or os.getenv('HOME')) .. '/.textadept'
package.path = string.format('%s/modules/?.lua;%s/modules/?/init.lua;%s', userhome, userhome, package.path)

local diff = require('tagit.diff')

-- Helper: build a diff string from an array of lines.
-- Simulates what git.run() returns (trailing newline present).
local function diff_text(lines)
  return table.concat(lines, '\n') .. '\n'
end

-- Helper: check a string contains a substring (plain, no pattern matching).
local function str_contains(s, sub)
  return s:find(sub, 1, true) ~= nil
end

-- diff.parse ---------------------------------------------------------------

test('diff.parse returns nil for nil input', function()
  test.assert_equal(nil, diff.parse(nil))
end)

test('diff.parse returns nil for empty input', function()
  test.assert_equal(nil, diff.parse(''))
end)

test('diff.parse returns nil for header-only diff (no hunks)', function()
  local text = diff_text({
    'diff --git a/file.lua b/file.lua',
    'index abc1234..def5678 100644',
    '--- a/file.lua',
    '+++ b/file.lua',
  })
  test.assert_equal(nil, diff.parse(text))
end)

test('diff.parse returns header and hunks for single-hunk diff', function()
  local text = diff_text({
    'diff --git a/f b/f',
    'index abc..def 100644',
    '--- a/f',
    '+++ b/f',
    '@@ -1,1 +1,2 @@',
    ' a',
    '+b',
  })
  local result = diff.parse(text)
  test.assert(result, 'expected parse result')
  test.assert(str_contains(result.header, 'diff --git a/f b/f'), 'header missing diff line')
  test.assert(str_contains(result.header, '--- a/f'), 'header missing --- line')
  test.assert(str_contains(result.header, '+++ b/f'), 'header missing +++ line')
  test.assert_equal(1, #result.hunks)
  test.assert_equal('@@ -1,1 +1,2 @@', result.hunks[1].header)
  test.assert_equal(4, #result.hunks[1].lines) -- @@ + ' a' + '+b' + '' (trailing empty)
  test.assert(str_contains(result.hunks[1].text, '@@ -1,1 +1,2 @@'), 'hunk text missing @@')
  test.assert(str_contains(result.hunks[1].text, '+b'), 'hunk text missing +b')
end)

test('diff.parse handles multi-hunk diff', function()
  local text = diff_text({
    'diff --git a/f b/f',
    'index abc..def 100644',
    '--- a/f',
    '+++ b/f',
    '@@ -1,3 +1,4 @@',
    ' a',
    '+b',
    ' c',
    '@@ -10,5 +11,6 @@',
    ' x',
    '+y',
    ' z',
  })
  local result = diff.parse(text)
  test.assert(result, 'expected parse result')
  test.assert_equal(2, #result.hunks)
  test.assert_equal('@@ -1,3 +1,4 @@', result.hunks[1].header)
  test.assert_equal(4, #result.hunks[1].lines) -- @@ + ' a' + '+b' + ' c' (no trailing empty)
  test.assert_equal('@@ -10,5 +11,6 @@', result.hunks[2].header)
  test.assert_equal(5, #result.hunks[2].lines) -- @@ + ' x' + '+y' + ' z' + '' (trailing empty)
end)

test('diff.parse handles hunks with various line types', function()
  local text = diff_text({
    'diff --git a/f b/f',
    'index abc..def 100644',
    '--- a/f',
    '+++ b/f',
    '@@ -1,3 +1,3 @@',
    ' line1',
    '-old',
    '+new',
    ' line3',
  })
  local result = diff.parse(text)
  test.assert(result, 'expected parse result')
  test.assert_equal(1, #result.hunks)
  test.assert_equal(6, #result.hunks[1].lines) -- @@ + ' line1' + '-old' + '+new' + ' line3' + '' (trailing empty)
  test.assert_equal(' line1', result.hunks[1].lines[2])
  test.assert_equal('-old', result.hunks[1].lines[3])
  test.assert_equal('+new', result.hunks[1].lines[4])
  test.assert_equal(' line3', result.hunks[1].lines[5])
end)

test('diff.parse preserves header content exactly', function()
  local header_lines = {
    'diff --git a/src/main.c b/src/main.c',
    'index f00..bar 100755',
    '--- a/src/main.c',
    '+++ b/src/main.c',
  }
  local text = diff_text({
    header_lines[1],
    header_lines[2],
    header_lines[3],
    header_lines[4],
    '@@ -42,6 +42,8 @@',
    ' unchanged',
    '+added1',
    '+added2',
  })
  local result = diff.parse(text)
  test.assert(result, 'expected parse result')
  for _, h in ipairs(header_lines) do
    test.assert(str_contains(result.header, h), 'header missing: ' .. h)
  end
end)

test('diff.parse handles empty hunk body', function()
  local text = diff_text({
    'diff --git a/f b/f',
    'index abc..def 100644',
    '--- a/f',
    '+++ b/f',
    '@@ -1,0 +1,0 @@',
  })
  local result = diff.parse(text)
  test.assert(result, 'expected parse result')
  test.assert_equal(1, #result.hunks)
  test.assert_equal(2, #result.hunks[1].lines) -- @@ line + trailing empty
end)

-- diff.parse_conflicts ----------------------------------------------------

test('diff.parse_conflicts returns empty list for no conflicts', function()
  local text = table.concat({ 'line1', 'line2', '' }, '\n')
  local result = diff.parse_conflicts(text)
  test.assert_equal(0, #result)
end)

test('diff.parse_conflicts returns empty list for text with no markers', function()
  local text = table.concat({
    'function foo()',
    '  return 42',
    'end',
    '',
  }, '\n')
  local result = diff.parse_conflicts(text)
  test.assert_equal(0, #result)
end)

test('diff.parse_conflicts detects 2-way conflict', function()
  local text = table.concat({
    '<<<<<<< HEAD',
    'our line',
    '=======',
    'their line',
    '>>>>>>> branch',
    '',
  }, '\n')
  local result = diff.parse_conflicts(text)
  test.assert_equal(1, #result)
  -- ours: from <<<<<<< to before ======= (including <<<<<<< line)
  test.assert_equal(2, #result[1].ours)
  test.assert_equal('<<<<<<< HEAD', result[1].ours[1])
  test.assert_equal('our line', result[1].ours[2])
  -- base: empty for 2-way
  test.assert_equal(0, #result[1].base)
  -- theirs: from after ======= to >>>>>>> (including >>>>>>> line)
  test.assert_equal(2, #result[1].theirs)
  test.assert_equal('their line', result[1].theirs[1])
  test.assert_equal('>>>>>>> branch', result[1].theirs[2])
end)

test('diff.parse_conflicts detects diff3-style conflict', function()
  local text = table.concat({
    '<<<<<<< HEAD',
    'our line',
    '||||||| merged common ancestor',
    'base line',
    '=======',
    'their line',
    '>>>>>>> branch',
    '',
  }, '\n')
  local result = diff.parse_conflicts(text)
  test.assert_equal(1, #result)
  test.assert_equal(2, #result[1].ours)
  test.assert_equal('<<<<<<< HEAD', result[1].ours[1])
  test.assert_equal('our line', result[1].ours[2])
  test.assert_equal(2, #result[1].base)
  test.assert_equal('||||||| merged common ancestor', result[1].base[1])
  test.assert_equal('base line', result[1].base[2])
  -- theirs: from after ======= to >>>>>>> (including >>>>>>> line)
  test.assert_equal(2, #result[1].theirs)
  test.assert_equal('their line', result[1].theirs[1])
  test.assert_equal('>>>>>>> branch', result[1].theirs[2])
end)

test('diff.parse_conflicts handles multiple conflicts', function()
  local text = table.concat({
    '<<<<<<< HEAD', -- conflict 1 start
    'a',
    '=======',
    'b',
    '>>>>>>> branch',
    'unchanged line',
    '<<<<<<< HEAD', -- conflict 2 start
    'c',
    '=======',
    'd',
    '>>>>>>> branch',
    '',
  }, '\n')
  local result = diff.parse_conflicts(text)
  test.assert_equal(2, #result)
end)

test('diff.parse_conflicts handles malformed conflict without =======', function()
  -- When ======= is missing, the parser cannot detect the conflict boundaries.
  local text = table.concat({
    '<<<<<<< HEAD',
    'our line',
    '>>>>>>> branch',
    '',
  }, '\n')
  local result = diff.parse_conflicts(text)
  test.assert_equal(0, #result)
end)

test('diff.parse_conflicts ignores markers inside string literals', function()
  -- Lines that contain marker-like text but not at start of line should not match.
  local text = table.concat({
    'local s = "<<<<<<< HEAD"  -- string literal, not a conflict',
    'local t = "======="',
    '',
  }, '\n')
  local result = diff.parse_conflicts(text)
  test.assert_equal(0, #result)
end)

test('diff.parse_conflicts handles markers at end of file without trailing newline', function()
  local text = table.concat({
    '<<<<<<< HEAD',
    'our line',
    '=======',
    'their line',
    '>>>>>>> branch',
  }, '\n')
  -- No trailing newline: parser should still find the conflict.
  local result = diff.parse_conflicts(text)
  test.assert_equal(1, #result)
  test.assert_equal(2, #result[1].ours)
  test.assert_equal(2, #result[1].theirs)
end)
