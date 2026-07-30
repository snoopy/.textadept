-- Tests for tagit.common utility functions.

local userhome = (os.getenv('USERPROFILE') or os.getenv('HOME')) .. '/.textadept'
package.path = string.format('%s/modules/?.lua;%s/modules/?/init.lua;%s', userhome, userhome, package.path)

local common = require('tagit.common')

-- common.fit(s, width) ----------------------------------------------------
-- Truncates `s` to `width` bytes, backs off if the last byte is part of a
-- multi-byte UTF-8 sequence, then right-pads with spaces to exactly `width`.

test('common.fit pads short strings with spaces', function()
  test.assert_equal('hello  ', common.fit('hello', 7))
end)

test('common.fit returns exactly width for exact match', function()
  test.assert_equal('hello', common.fit('hello', 5))
end)

test('common.fit returns empty string padded for empty input', function()
  test.assert_equal('     ', common.fit('', 5))
end)

test('common.fit truncates long strings', function()
  test.assert_equal('hello', common.fit('hello world', 5))
end)

test('common.fit handles nil input as empty string', function()
  test.assert_equal('   ', common.fit(nil, 3))
end)

test('common.fit backs off when truncation splits a multi-byte UTF-8 sequence', function()
  -- U+00E9 = é = 0xC3 0xA9 in UTF-8 (2 bytes)
  local s = 'caf\u{00E9}'
  test.assert_equal(5, #s) -- 'caf' + 2 byte é
  -- Width 4 should truncate to byte 4: 'caf\xC3', then back off the continuation byte -> 'caf', pad -> 'caf '
  test.assert_equal('caf ', common.fit(s, 4))
end)

test('common.fit keeps exact multi-byte sequence at boundary', function()
  local s = 'caf\u{00E9}'
  test.assert_equal('caf\u{00E9}', common.fit(s, 5))
end)

test('common.fit backs off multi-byte sequence straddling the truncation boundary', function()
  -- 'caf\u{00E9}s' = 6 bytes. Width 5 truncates to byte 5 = 0xA9 (continuation byte)
  local s = 'caf\u{00E9}s'
  test.assert_equal('caf  ', common.fit(s, 5)) -- 'caf' + 2 spaces = 5
  test.assert_equal('caf\u{00E9}s', common.fit(s, 6)) -- exact = 6 bytes (no pad needed)
  test.assert_equal('caf\u{00E9}s ', common.fit(s, 7)) -- 6 bytes + 1 space = 7
end)

test('common.fit handles multi-byte sequences with leading byte at boundary', function()
  local s = '\u{4E16}\u{4E16}\u{4E16}'
  test.assert_equal(9, #s)
  local r6 = common.fit(s, 6)
  test.assert_equal(6, #r6, 'width 6 result length')
  test.assert(r6:byte(1) >= 0xE4, 'expected non-ASCII byte at pos 1')
  test.assert_equal('  ', common.fit(s, 2))
end)

test('common.fit handles mixed ASCII and multi-byte content', function()
  local s = 'abc\u{00E9}def' -- 8 bytes: a,b,c,é(2),d,e,f
  test.assert_equal(8, #s)
  -- Width 7: truncates 'abcéde' (7 bytes, no continuation at end) -> padded to 7
  test.assert_equal('abc\u{00E9}de', common.fit(s, 7))
  test.assert_equal('abc\u{00E9}d', common.fit(s, 6))
  test.assert_equal('abc', common.fit(s, 3))
end)

test('common.fit handles very long width', function()
  local s = 'hello'
  test.assert_equal('hello      ', common.fit(s, 11))
end)

test('common.fit handles width of 0', function()
  test.assert_equal('', common.fit('hello', 0))
  test.assert_equal('', common.fit('', 0))
  test.assert_equal('', common.fit(nil, 0))
end)
