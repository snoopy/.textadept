-- Low-level git plumbing for the tagit module.
--
-- This module is intentionally UI-free. It locates the repository, runs git commands
-- (synchronously or asynchronously via os.spawn) and
-- parses porcelain output into plain Lua tables that the UI modules render.

local lfs = require('lfs')

local M = {}

-- Strip trailing whitespace.
local function trim(s)
  return (tostring(s):gsub('%s+$', ''))
end

-- Module variable for controlling the commit date.
-- Set to nil to use git's default (author's local time).
-- Set to a date string to pass it as --date to git commit.
-- Set to a function that returns a date string for dynamic dates.
-- Default: a function returning the current UTC time.
M.commit_date = function()
  return os.date('!%Y-%m-%d %H:%M:%S +0000')
end

-- Shell-quote a single argument for POSIX shells.
-- Wraps in single quotes and escapes embedded single quotes the usual `'\''` way.
-- As usual, windows needs special care.
local function shquote(str)
  str = tostring(str)
  if OS == 'windows' then
    str = str:gsub('(\\*)"', '%1%1\\"'):gsub('(\\+)$', '%1%1')
    return '"' .. str .. '"'
  end
  return "'" .. str:gsub("'", [['\'']]) .. "'"
end
M.quote = shquote

-- Write `content` to a temporary file, call `fn(path)`, then remove the file (even if `fn` errors).
-- Used to pass patches and commit messages to git via a file rather than a pipe,
-- which avoids managing a bidirectional pipe and is robust across platforms.
-- Returns whatever `fn` returns, or `false, error` if `fn` raised.
-- The wrapped function should return `(out, code)` where out is string and code is exit code.
local function with_temp_file(content, fn)
  local tmp = os.tmpname()
  local f, err = io.open(tmp, 'wb')
  if not f then return nil, err end
  f:write(content)
  f:close()
  local ok_call, a, b = pcall(fn, tmp)
  os.remove(tmp)
  if not ok_call then return nil, a end
  return a, b -- (out, code) from fn
end

---
-- Returns the absolute path of the project root,
-- or nil when the path is not part of a git work tree.
-- When @{path} is omitted, the current buffer's directory is used.
-- @param path Optional file/directory path to find the root for.
function M.root(path)
  return io.get_project_root(path, true)
end

-- Check whether a file exists using lfs, without opening a handle.
local function file_exists(path)
  local attr = lfs.attributes(path)
  return attr ~= nil and attr.mode == 'file'
end

---
-- Runs a git command synchronously inside `root` (defaults to @{M.root}).
-- @param args A string of already-quoted git arguments, e.g. `'status -s'`.
-- @param root Optional repository root. When omitted, @{M.root} is used.
-- @param env Optional table of environment variables to set before running the command.
-- @return stdout+stderr as a string, or nil plus an error message.
-- @return exit code (number) on success.
function M.run(args, root, env)
  root = root or M.root()
  if not root then return nil, 'not a git repository' end
  local env_prefix = ''
  if env then
    if OS == 'windows' then
      local parts = {}
      for k, v in pairs(env) do
        local val = tostring(v):gsub('"', '""')
        parts[#parts + 1] = 'set "' .. k .. '=' .. val .. '"'
      end
      env_prefix = table.concat(parts, ' && ') .. ' && '
    else
      local parts = {}
      for k, v in pairs(env) do
        parts[#parts + 1] = k .. '=' .. shquote(tostring(v))
      end
      env_prefix = table.concat(parts, ' ') .. ' '
    end
  end
  local cmd = env_prefix .. 'git -C ' .. shquote(root) .. ' ' .. args
  if OS == 'windows' then
    local proc = os.spawn(cmd, root)
    if not proc then return nil, 'failed to spawn git' end
    local out = proc:read('a') or ''
    local code = proc:wait()
    return out, code
  end
  local proc = io.popen(cmd .. ' 2>&1')
  if not proc then return nil, 'failed to spawn git' end
  local out = proc:read('*a') or ''
  local _, _, code = proc:close()
  return out, code or 0
end

---
-- Runs a git command and feeds `input` to it on stdin (synchronously).
-- Used for `git apply` with a patch built in memory.
-- @param args Already-quoted git arguments.
-- @param input String written to the process's stdin.
-- @param root Optional repository root.
-- @return (out, code) where out is output string and code is exit code.
function M.run_with_input(args, input, root)
  root = root or M.root()
  if not root then return nil, 'not a git repository' end
  return with_temp_file(input, function(tmp)
    return M.run(args .. ' ' .. shquote(tmp), root)
  end)
end

---
-- Runs a git command asynchronously and invokes `on_done(output, code)` on completion.
-- Intended for network operations (push/pull/fetch) so the UI does not block.
-- @param argv A string command line (without the leading `git`).
-- @param root Optional repository root. When omitted, @{M.root} is used.
-- @param on_done Callback receiving combined stdout/stderr and the exit code.
function M.run_async(argv, root, on_done)
  root = root or M.root()
  if not root then
    on_done('not a git repository', -1)
    return
  end
  local chunks = {}
  local function collect(chunk)
    chunks[#chunks + 1] = chunk
  end
  -- Use `git -C <root>` for parity with M.run (rather than relying on the spawn cwd).
  os.spawn('git -C ' .. shquote(root) .. ' ' .. argv, root, collect, collect, function(code)
    on_done(table.concat(chunks), code)
  end)
end

---
-- Runs a git command interactively (e.g. rebase --interactive) without blocking the UI.
-- Uses non-blocking os.spawn with callbacks, so Textadept's main thread stays responsive.
-- @param args Already-quoted git arguments, e.g. 'rebase --interactive HEAD~3'.
-- @param root Optional repository root.
-- @param env Optional table of environment variables (same format as @{M.run}).
-- @param on_done Callback invoked as `on_done(output, code)` when the process finishes.
function M.run_interactive(args, root, env, on_done)
  root = root or M.root()
  if not root then
    on_done('not a git repository', -1)
    return
  end
  local parts = {}
  if OS == 'windows' then
    if env then
      for k, v in pairs(env) do
        local val = tostring(v):gsub('"', '""')
        parts[#parts + 1] = 'set "' .. k .. '=' .. val .. '"'
      end
    end
    parts[#parts + 1] = 'git -C ' .. shquote(root) .. ' ' .. args
  else
    if env then
      for k, v in pairs(env) do
        parts[#parts + 1] = k .. '=' .. shquote(tostring(v))
      end
    end
    parts[#parts + 1] = 'git -C ' .. shquote(root) .. ' ' .. args
  end
  local sep = OS == 'windows' and ' && ' or ' '
  local cmd = table.concat(parts, sep)
  local chunks = {}
  local function collect(chunk)
    chunks[#chunks + 1] = chunk
  end
  os.spawn(cmd, root, collect, collect, function(code)
    on_done(table.concat(chunks), code)
  end)
end

---
-- Collects repository status into a structured table.
-- @param root Optional repository root.
-- @return a table with `branch` (table with `head`, `upstream`, `ahead`, `behind`),
-- `staged`, `unstaged`, `untracked`, `unmerged`, and `files` (array of `{ path, status, orig }`)
-- fields, or nil plus an error message.
function M.status(root)
  root = root or M.root()
  if not root then return nil, 'not a git repository' end
  local out, code = M.run('-c core.quotePath=false status --short --branch', root)
  if not out or code ~= 0 then return nil, out or 'git status failed' end

  local status = {
    branch = { head = nil, upstream = nil, ahead = 0, behind = 0 },
    staged = {},
    unstaged = {},
    untracked = {},
    unmerged = {},
    files = {},
  }

  for line in out:gmatch('[^\n]+') do
    if line:match('^## ') then
      local rest = line:match('^## (.+)$')
      if rest then
        local head, upstream = rest:match('(.-)%.%.%.(.+)')
        if head then
          status.branch.head = head
          if upstream then
            upstream = upstream:gsub(' %[.+%]$', ''):gsub(' %+[^%+]+%+$', '')
            status.branch.upstream = upstream
          end
          local ahead = rest:match('ahead (%d+)')
          local behind = rest:match('behind (%d+)')
          status.branch.ahead = tonumber(ahead) or 0
          status.branch.behind = tonumber(behind) or 0
        else
          status.branch.head = rest:gsub(' %[.+%]$', ''):gsub(' %+[^%+]+%+$', ''):gsub('%.%.%.', '')
        end
      end
    elseif line:match('^(..) (.*)$') then
      local xy, path = line:match('^(..) (.*)$')
      local x, y = xy:sub(1, 1), xy:sub(2, 2)
      local orig
      if x == 'R' or y == 'R' then
        local old, new = path:match('^(.+) %-> (.+)$')
        if old and new then
          orig = old
          path = new
        end
      end
      status.files[#status.files + 1] = { path = path, status = xy, orig = orig }
      if xy == '??' then
        status.untracked[#status.untracked + 1] = { path = path }
      elseif x == 'U' or y == 'U' then
        status.unmerged[#status.unmerged + 1] = { path = path, status = 'U' }
      else
        if x ~= ' ' then status.staged[#status.staged + 1] = { path = path, orig = orig, status = x } end
        if y ~= ' ' then status.unstaged[#status.unstaged + 1] = { path = path, orig = orig, status = y } end
      end
    end
  end

  return status
end

---
-- Detects an in-progress merge, rebase, or cherry-pick operation.
-- @param root Optional repository root.
-- @return nil when idle, or a table with `type` (`'merge'`, `'rebase'`, or `'cherry-pick'`).
-- For merge: includes `head` (current branch) and `branch` (merge subject).
-- For rebase: includes `branch` (onto), `progress`, `total`.
-- For cherry-pick: includes `branch` (current branch) and `subject` (commit subject).
function M.operation(root)
  root = root or M.root()
  if not root then return nil end
  local out = M.run('rev-parse --git-dir', root)
  if not out then return nil end
  local git_dir = out:match('^%s*(.-)%s*$') or out
  if not git_dir:match('^[/\\]') and not git_dir:match('^%a:') then git_dir = root .. '/' .. git_dir end
  -- Resolve .git file (common in worktrees and submodules).
  if file_exists(git_dir) then
    local f = io.open(git_dir, 'r')
    local content = f and f:read('*a')
    if f then f:close() end
    local actual = content and content:match('gitdir:%s*(.+)')
    if actual then
      actual = trim(actual)
      if not actual:match('^[/\\]') and not actual:match('^%a:') then actual = root .. '/' .. actual end
      git_dir = actual
    end
  end
  -- Check for merge state.
  if file_exists(git_dir .. '/MERGE_HEAD') then
    local branch = trim((M.run('symbolic-ref HEAD', root) or ''):gsub('^refs/heads/', ''))
    local msg = M.run('log --oneline -1 MERGE_HEAD', root) or ''
    local subject = trim(msg:gsub('^%S+%s+', ''))
    return { type = 'merge', head = branch, branch = subject, progress = nil, total = nil }
  end
  -- Check for rebase state.
  if file_exists(git_dir .. '/rebase-merge/msgnum') then
    local f = io.open(git_dir .. '/rebase-merge/msgnum')
    local msgnum = f and trim(f:read('*a'))
    if f then f:close() end
    local total = '?'
    if file_exists(git_dir .. '/rebase-merge/end') then
      local endf = io.open(git_dir .. '/rebase-merge/end')
      total = endf and trim(endf:read('*a')) or '?'
      if endf then endf:close() end
    end
    local onto = trim((M.run('symbolic-ref HEAD', root) or ''):gsub('^refs/heads/', ''))
    return { type = 'rebase', branch = onto, progress = msgnum, total = total }
  end
  -- Check for rebase-apply (git-am based rebase, less common).
  if file_exists(git_dir .. '/rebase-apply/next') then
    local f = io.open(git_dir .. '/rebase-apply/next')
    local next = f and trim(f:read('*a'))
    if f then f:close() end
    local total = '?'
    if file_exists(git_dir .. '/rebase-apply/last') then
      local endf = io.open(git_dir .. '/rebase-apply/last')
      total = endf and trim(endf:read('*a')) or '?'
      if endf then endf:close() end
    end
    return { type = 'rebase', progress = next, total = total }
  end
  -- Check for cherry-pick state.
  if file_exists(git_dir .. '/CHERRY_PICK_HEAD') then
    local onto = trim((M.run('symbolic-ref HEAD', root) or ''):gsub('^refs/heads/', ''))
    local msg = M.run('log --oneline -1 CHERRY_PICK_HEAD', root) or ''
    local subject = trim(msg:gsub('^%S+%s+', ''))
    return { type = 'cherry-pick', branch = onto, subject = subject }
  end
  return nil
end

---
-- Checkout a file using the ours version (during merge/rebase conflict).
-- @param path File path relative to the repository root.
-- @param root Optional repository root.
-- @return (out, code) from M.run.
function M.checkout_ours(path, root)
  root = root or M.root()
  if not root then return nil, 'not a git repository' end
  return M.run('checkout --ours -- ' .. shquote(path), root)
end

---
-- Checkout a file using the theirs version (during merge/rebase conflict).
-- @param path File path relative to the repository root.
-- @param root Optional repository root.
-- @return (out, code) from M.run.
function M.checkout_theirs(path, root)
  root = root or M.root()
  if not root then return nil, 'not a git repository' end
  return M.run('checkout --theirs -- ' .. shquote(path), root)
end

---
-- Returns the most recent commits as a list of `{ sha, subject }` tables.
-- @param count Number of commits to fetch (default 10).
-- @param root Optional repository root.
function M.recent_commits(count, root)
  count = count or 10
  local SEP = string.char(31)
  local out, code = M.run('log --no-color --pretty=' .. shquote('format:%h%x1f%s') .. ' -n ' .. count, root)
  if not out or code ~= 0 then return {} end
  local commits = {}
  for line in out:gmatch('[^\n]+') do
    local sha, subject = line:match('^(%S+)' .. SEP .. '(.*)$')
    if sha then commits[#commits + 1] = { sha = sha, subject = subject } end
  end
  return commits
end

---
-- Returns the current stash entries as a list of `{ ref, subject }` tables.
function M.stashes(root)
  local SEP = string.char(31)
  local out, code = M.run('stash list --pretty=' .. shquote('format:%gd%x1f%s'), root)
  if not out or code ~= 0 or out == '' then return {} end
  local stashes = {}
  for line in out:gmatch('[^\n]+') do
    local ref, subject = line:match('^(%S+)' .. SEP .. '(.*)$')
    if ref then stashes[#stashes + 1] = { ref = ref, subject = subject } end
  end
  return stashes
end

---
-- Returns the diff text for a single file.
-- @param path File path relative to the repository root.
-- @param staged When true, returns the staged (index) diff; otherwise the working-tree diff.
-- @param root Optional repository root.
function M.file_diff(path, staged, root)
  local args = 'diff --no-color' .. (staged and ' --cached' or '') .. ' -- ' .. shquote(path)
  local out = M.run(args, root)
  return out or ''
end

---
-- Runs a single `git diff` and returns per-file diff text keyed by path.
-- @param staged When true, returns the staged (index) diffs; otherwise the working-tree diffs.
-- @param root Repository root.
-- @return { [path] = raw_diff_text } or {}.
function M.file_diffs(staged, root)
  local args = 'diff --no-color' .. (staged and ' --cached' or '')
  local out, code = M.run(args, root)
  if code ~= 0 or not out then return {} end
  local result = {}
  local path, text
  for line in out:gmatch('[^\n]+') do
    local p = line:match('^diff %-%-git a/.+ b/(.+)$')
    if p then
      if path then result[path] = text end
      path = p
      text = line .. '\n'
    elseif path then
      text = text .. line .. '\n'
    end
  end
  if path then result[path] = text end
  return result
end

---
-- Returns an env table with GIT_COMMITTER_DATE set when M.commit_date is configured,
-- or nil when no date override is in effect.
-- Intended for passing as the env argument to M.run() for any command that creates a commit
-- (merge, rebase, stash push, etc.).
function M.date_env()
  if not M.commit_date then return nil end
  local date_str = type(M.commit_date) == 'function' and M.commit_date() or M.commit_date
  return { GIT_COMMITTER_DATE = date_str, GIT_AUTHOR_DATE = date_str }
end

-- Begin high-level actions.
-- These return (out, code) where out is output string and code is exit code,
-- consistent with M.run(). Callers check code == 0 for success.

---
-- Stages a file to the index.
-- @param path File path relative to the repository root.
-- @param root Optional repository root.
-- @return (out, code) from M.run.
function M.stage(path, root)
  return M.run('add -- ' .. shquote(path), root)
end

---
-- Stages all updated changes in the working tree to the index.
function M.stage_updated(root)
  return M.run('add --update', root)
end

---
-- Stages all changes in the working tree to the index, including untracked files.
function M.stage_all(root)
  return M.run('add --all', root)
end

---
-- Unstages a file from the index.
function M.unstage(path, root)
  return M.run('restore --staged -- ' .. shquote(path), root)
end

---
-- Unstages all files from the index.
function M.unstage_all(root)
  return M.run('restore --staged :/', root)
end

---
-- Discards working-tree changes for a tracked file.
function M.checkout_file(path, root)
  return M.run('checkout -- ' .. shquote(path), root)
end

---
-- Removes an untracked file from disk.
function M.remove_untracked(path, root)
  return M.run('clean --force -- ' .. shquote(path), root)
end

---
-- Resets HEAD using the given mode, optionally to a specific ref.
-- @param mode `'hard'`, `'soft'`, or `'mixed'`.
-- @param ref Optional ref to reset to (e.g. `'HEAD~1'`, a commit hash, branch). When nil, resets HEAD.
-- @param root Optional repository root.
-- @return (out, code) from M.run.
function M.reset(mode, ref, root)
  local args = 'reset --' .. mode
  if ref then args = args .. ' ' .. shquote(ref) end
  return M.run(args, root)
end

---
-- Removes untracked files and directories, optionally also ignored files.
function M.clean(root, purge)
  local args = purge and 'clean -d --force -x --force' or 'clean -d --force'
  return M.run(args, root)
end

---
-- Creates a commit with the given message, optionally amending HEAD.
-- @param message Commit message text.
-- @param amend When true, amend the previous commit instead of creating a new one.
-- @param root Optional repository root.
-- @return (out, code) from M.run.
function M.commit(message, amend, root)
  root = root or M.root()
  if not root then return nil, 'not a git repository' end
  -- Pass the message via a temp file (-F) to avoid shell-quoting the message body.
  return with_temp_file(message, function(tmp)
    local date_arg = ''
    local env = M.date_env()
    if env then date_arg = ' --date ' .. shquote(env.GIT_COMMITTER_DATE) end
    local args = 'commit --file ' .. shquote(tmp) .. date_arg .. (amend and ' --amend' or '')
    return M.run(args, root, env)
  end)
end

---
-- Amends HEAD without editing the commit message.
-- @param root Optional repository root.
-- @return (out, code) from M.run.
function M.commit_amend_no_edit(root)
  root = root or M.root()
  if not root then return nil, 'not a git repository' end
  local date_arg = ''
  local env = M.date_env()
  if env then date_arg = ' --date ' .. shquote(env.GIT_COMMITTER_DATE) end
  return M.run('commit --amend --no-edit' .. date_arg, root, env)
end

---
-- Returns the full diff for a stash entry.
-- @param ref Stash reference, e.g. `stash@{0}`.
-- @param root Optional repository root.
-- @return The patch text (may be empty if the stash has no tracked changes).
function M.stash_show(ref, root)
  local out = M.run('stash show --patch ' .. shquote(ref), root)
  return out or ''
end

---
-- Cherry-pick a single commit.
-- @param sha The commit hash to cherry-pick.
-- @param root Optional repository root.
-- @return (out, code) from M.run.
function M.cherry_pick(sha, root)
  return M.run('cherry-pick ' .. shquote(sha), root, M.date_env())
end

---
-- Continue a cherry-pick after resolving conflicts.
function M.cherry_pick_continue(root)
  return M.run('cherry-pick --continue', root, M.date_env())
end

---
-- Abort a cherry-pick in progress.
function M.cherry_pick_abort(root)
  return M.run('cherry-pick --abort', root)
end

---
-- Skip the current commit and continue the cherry-pick sequence.
function M.cherry_pick_skip(root)
  return M.run('cherry-pick --skip', root, M.date_env())
end

---
-- Revert a single commit by creating an anti-commit on top of HEAD.
function M.revert(sha, root)
  return M.run('revert --no-edit ' .. shquote(sha), root, M.date_env())
end

---
-- Returns commits reachable from `branch` but not from HEAD.
-- @param branch Remote or local branch name.
-- @param count Maximum number of commits (default 20).
-- @param root Optional repository root.
-- @return a list of `{ sha, subject }` tables.
function M.branch_commits(branch, count, root)
  count = count or 20
  root = root or M.root()
  if not root then return {} end
  local SEP = string.char(31)
  local out, code = M.run(
    'log --no-merges --oneline --no-color --pretty='
      .. shquote('format:%h%x1f%s')
      .. ' -n '
      .. count
      .. ' '
      .. shquote(branch)
      .. ' --not HEAD',
    root
  )
  if not out or code ~= 0 then return {} end
  local commits = {}
  for line in out:gmatch('[^\n]+') do
    local sha, subject = line:match('^(%S+)' .. SEP .. '(.*)$')
    if sha then commits[#commits + 1] = { sha = sha, subject = subject } end
  end
  return commits
end

---
-- Runs git blame on a file and returns per-line annotation data.
-- Each entry: { sha, orig_line, final_line, author, author_time,
--               committer_time, summary, content }
-- Returns nil, error_message on failure.
-- @param path File path relative to the repository root.
-- @param root Optional repository root.
-- @param revision Optional revision to blame against (default: HEAD).
function M.blame(path, root, revision)
  root = root or M.root()
  if not root then return nil, 'not a git repository' end
  local rev_arg = revision and ' ' .. shquote(revision) or ''
  local out, code = M.run('blame --line-porcelain' .. rev_arg .. ' -- ' .. shquote(path), root)
  if not out or code ~= 0 then return nil, trim(out or 'git blame failed') end
  local result = {}
  local entry = nil
  for line in out:gmatch('[^\n]+') do
    local sha1, _, final_ln = line:match('^(%x+) (%d+) (%d+)')
    if sha1 and sha1:match('^%x+$') then
      entry = {
        sha = sha1,
        final_line = tonumber(final_ln),
        author = '',
        author_time = 0,
        committer_time = 0,
        summary = '',
        content = '',
      }
      result[#result + 1] = entry
    elseif entry and entry.content == '' and not line:match('^\t') then
      local val
      val = line:match('^author (.+)$')
      if val then entry.author = val end
      val = line:match('^author%-time (%d+)')
      if val then entry.author_time = tonumber(val) or 0 end
      val = line:match('^committer%-time (%d+)')
      if val then entry.committer_time = tonumber(val) or 0 end
      val = line:match('^summary (.+)$')
      if val then entry.summary = val end
    end
    if entry and line:match('^\t') then entry.content = line:sub(2) end
  end
  return result
end

---
-- Returns the parent SHA of a commit, or nil if it has no parent (root commit).
function M.parent_sha(sha, root)
  if not sha then return nil end
  local out, code = M.run('rev-parse ' .. shquote(sha .. '~1'), root)
  if code ~= 0 or not out then return nil end
  return trim(out)
end

return M
