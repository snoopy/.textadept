-- Tests for tagit.git parsing functions (git.status, git.blame).
-- These mock git.run() to provide controlled input without spawning actual git.

local userhome = (os.getenv('USERPROFILE') or os.getenv('HOME')) .. '/.textadept'
package.path = string.format('%s/modules/?.lua;%s/modules/?/init.lua;%s', userhome, userhome, package.path)

local git = require('tagit.git')

-- Shortcut: build a string from lines.
local EOL = '\n'
local function text(lines)
  return table.concat(lines, EOL) .. EOL
end

-- git.status --------------------------------------------------------------

test('git.status parses tracked branch with upstream', function()
  local _ <close> = test.mock(git, 'run', function()
    return text({ '## main...origin/main', ' M modified.lua', 'A  staged.lua', '?? untracked.lua' }), 0
  end)
  local result, err = git.status('/fake/repo')
  test.assert(result, 'expected status, got: ' .. tostring(err))
  test.assert_equal('main', result.branch.head)
  test.assert_equal('origin/main', result.branch.upstream)
  test.assert_equal(0, result.branch.ahead)
  test.assert_equal(0, result.branch.behind)
end)

test('git.status parses ahead/behind counts', function()
  local _ <close> = test.mock(git, 'run', function()
    return text({ '## feature...origin/feature [ahead 3, behind 1]', '' }), 0
  end)
  local result = git.status('/fake/repo')
  test.assert(result, 'expected status result')
  test.assert_equal('feature', result.branch.head)
  test.assert_equal('origin/feature', result.branch.upstream)
  test.assert_equal(3, result.branch.ahead)
  test.assert_equal(1, result.branch.behind)
end)

test('git.status detects gone upstream', function()
  local _ <close> = test.mock(git, 'run', function()
    return text({ '## branch...origin/branch [gone]', '' }), 0
  end)
  local result = git.status('/fake/repo')
  test.assert(result, 'expected status result')
  test.assert_equal(true, result.branch.gone)
end)

test('git.status parses staged files', function()
  local _ <close> = test.mock(git, 'run', function()
    return text({ '## main', 'M  staged.lua', 'A  added.lua', 'D  deleted.lua', '' }), 0
  end)
  local result = git.status('/fake/repo')
  test.assert(result, 'expected status result')
  test.assert_equal(3, #result.staged)
  test.assert_equal('staged.lua', result.staged[1].path)
  test.assert_equal('added.lua', result.staged[2].path)
  test.assert_equal('deleted.lua', result.staged[3].path)
end)

test('git.status parses unstaged files', function()
  local _ <close> = test.mock(git, 'run', function()
    return text({ '## main', ' M modified.lua', ' D deleted_working.lua', '' }), 0
  end)
  local result = git.status('/fake/repo')
  test.assert(result, 'expected status result')
  test.assert_equal(2, #result.unstaged)
  test.assert_equal('modified.lua', result.unstaged[1].path)
  test.assert_equal('deleted_working.lua', result.unstaged[2].path)
end)

test('git.status parses untracked files', function()
  local _ <close> = test.mock(git, 'run', function()
    return text({ '## main', '?? new_file.lua', '?? another.lua', '' }), 0
  end)
  local result = git.status('/fake/repo')
  test.assert(result, 'expected status result')
  test.assert_equal(2, #result.untracked)
  test.assert_equal('new_file.lua', result.untracked[1].path)
  test.assert_equal('another.lua', result.untracked[2].path)
end)

test('git.status parses renamed files', function()
  local _ <close> = test.mock(git, 'run', function()
    return text({ '## main', 'R  old.lua -> new.lua', '' }), 0
  end)
  local result = git.status('/fake/repo')
  test.assert(result, 'expected status result')
  test.assert_equal('new.lua', result.files[1].path)
  test.assert_equal('old.lua', result.files[1].orig)
end)

test('git.status parses renamed files in staged section', function()
  local _ <close> = test.mock(git, 'run', function()
    return text({ '## main', 'R  old_name.lua -> renamed.lua', '' }), 0
  end)
  local result = git.status('/fake/repo')
  test.assert(result, 'expected status result')
  test.assert_equal(1, #result.staged)
  test.assert_equal('renamed.lua', result.staged[1].path)
  test.assert_equal('old_name.lua', result.staged[1].orig)
end)

test('git.status parses unmerged files', function()
  local _ <close> = test.mock(git, 'run', function()
    return text({ '## main', 'UU conflicted.lua', '' }), 0
  end)
  local result = git.status('/fake/repo')
  test.assert(result, 'expected status result')
  test.assert_equal(1, #result.unmerged)
  test.assert_equal('conflicted.lua', result.unmerged[1].path)
end)

test('git.status parses both staged and unstaged for same file', function()
  local _ <close> = test.mock(git, 'run', function()
    return text({ '## main', 'MM both.lua', '' }), 0
  end)
  local result = git.status('/fake/repo')
  test.assert(result, 'expected status result')
  test.assert_equal(1, #result.staged)
  test.assert_equal('both.lua', result.staged[1].path)
  test.assert_equal(1, #result.unstaged)
  test.assert_equal('both.lua', result.unstaged[1].path)
end)

test('git.status handles mixed file statuses', function()
  local _ <close> = test.mock(git, 'run', function()
    return text({
      '## main',
      ' M  unstaged.lua',
      'M   staged.lua',
      'MM  both.lua',
      'D   deleted.lua',
      '??  new.lua',
      'UU  conflict.lua',
      '',
    }),
      0
  end)
  local result = git.status('/fake/repo')
  test.assert(result, 'expected status result')
  test.assert_equal(3, #result.staged)
  test.assert_equal(2, #result.unstaged)
  test.assert_equal(1, #result.untracked)
  test.assert_equal(1, #result.unmerged)
  test.assert_equal(6, #result.files)
end)

test('git.status handles detached HEAD', function()
  local _ <close> = test.mock(git, 'run', function(args, root, env)
    if args:match('status') then return text({ '## HEAD (no branch)', '' }), 0 end
    if args:match('rev%-parse') then return 'abc1234\n', 0 end
    return '', 0
  end)
  local result = git.status('/fake/repo')
  test.assert(result, 'expected status result')
  test.assert_equal('(abc1234)', result.branch.head)
end)

test('git.status handles empty repository (no commits)', function()
  local _ <close> = test.mock(git, 'run', function(args)
    if args:match('status') then return text({ '## No commits yet on main', '' }), 0 end
    return '', 0
  end)
  local result = git.status('/fake/repo')
  test.assert(result, 'expected status result')
  test.assert_equal('No commits yet on main', result.branch.head)
end)

test('git.status returns nil on git failure', function()
  local _ <close> = test.mock(git, 'run', function()
    return nil, 128
  end)
  local result, err = git.status('/fake/repo')
  test.assert_equal(nil, result)
  test.assert(err, 'expected error message')
end)

-- git.blame ---------------------------------------------------------------

test('git.blame parses line-porcelain output', function()
  local porcelain = table.concat({
    'abc12345678901234567890123456789012345678 1 1 1',
    'author Test Author',
    'author-mail <test@example.com>',
    'author-time 1700000000',
    'author-tz +0000',
    'committer Test Committer',
    'committer-mail <committer@example.com>',
    'committer-time 1700000000',
    'committer-tz +0000',
    'summary Fix the thing',
    'previous deadbeef file.lua',
    'filename file.lua',
    '\tcontent line 1',
    'abc12345678901234567890123456789012345678 2 2 2',
    'author Another Author',
    'author-mail <another@example.com>',
    'author-time 1700000001',
    'author-tz +0000',
    'committer Another Committer',
    'committer-mail <another-committer@example.com>',
    'committer-time 1700000001',
    'committer-tz +0000',
    'summary Another change',
    'previous feedbeef file.lua',
    'filename file.lua',
    '\tcontent line 2',
    '',
  }, EOL)
  local _ <close> = test.mock(git, 'run', function()
    return porcelain, 0
  end)
  local result, err = git.blame('file.lua', '/fake/repo')
  test.assert(result, 'expected blame data, got: ' .. tostring(err))
  test.assert_equal(2, #result)
  test.assert_equal('abc12345678901234567890123456789012345678', result[1].sha)
  test.assert_equal(1, result[1].final_line)
  test.assert_equal('Test Author', result[1].author)
  test.assert_equal(1700000000, result[1].author_time)
  test.assert_equal('content line 1', result[1].content)
  test.assert_equal('Another Author', result[2].author)
  test.assert_equal('content line 2', result[2].content)
end)

test('git.blame handles uncommitted lines (all-zero SHA)', function()
  local porcelain = table.concat({
    '0000000000000000000000000000000000000000 1 1 1',
    'author Not Committed Yet',
    'author-mail <not.committed@example.com>',
    'author-time 1700000000',
    'author-tz +0000',
    'committer Not Committed Yet',
    'committer-mail <not.committed@example.com>',
    'committer-time 1700000000',
    'committer-tz +0000',
    'summary Uncommitted change',
    'filename file.lua',
    '\tuncommitted content',
    '',
  }, EOL)
  local _ <close> = test.mock(git, 'run', function()
    return porcelain, 0
  end)
  local result = git.blame('file.lua', '/fake/repo')
  test.assert(result, 'expected blame data')
  test.assert_equal(1, #result)
  test.assert(result[1].sha:match('^0+$'), 'expected all-zero SHA')
end)

test('git.blame handles empty file', function()
  local _ <close> = test.mock(git, 'run', function()
    return '', 0
  end)
  local result, err = git.blame('empty.lua', '/fake/repo')
  test.assert(result, 'expected blame data')
  test.assert_equal(0, #result)
end)

test('git.blame returns nil on git error', function()
  local _ <close> = test.mock(git, 'run', function()
    return 'fatal: not a git repository', 128
  end)
  local result, err = git.blame('file.lua', '/fake/repo')
  test.assert_equal(nil, result)
  test.assert(err, 'expected error message')
end)
