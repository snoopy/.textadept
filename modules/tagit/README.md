# tagit

A [Magit](https://magit.vc/)-inspired git porcelain for Textadept.

## Installation

Copy to `~/.textadept/modules/tagit/` and add to `init.lua`:

```lua
local tagit = require('tagit')
```

To add keybindings, e.g.:

```lua
keys['ctrl+alt+g'] = tagit.status
keys['ctrl+alt+l'] = tagit.log
```

## Public API

| Function | Description |
|---|---|
| `tagit.status()` | Open the status buffer |
| `tagit.log([ref])` | Open the log buffer (optionally for a branch/ref) |
| `tagit.commit([amend])` | Start a commit (pass `true` to amend) |
| `tagit.stash_list()` | Open the stash list buffer |
| `tagit.branch_list([mode])` | Open the branch list buffer (`'local'` or `'remote'`) |
| `tagit.reload()` | Fetch + hard reset to `@{upstream}` (asks confirmation) |
| `tagit.rebase_interactive([base])` | Start an interactive rebase |
| `tagit.console()` | Open the git console (type commands, see output) |

### Advanced

| Property | Description |
|---|---|
| `tagit.git` | The full git module — access `git.run()`, `git.run_async()`, `git.quote()`, etc. |
| `tagit.git.commit_date` | Date string/function for commits (see Configuration below) |
| `tagit.log_module.max_commits` | Max commits shown in log buffer (default 200) |
| `tagit.status_module.refresh()` | Refresh the status buffer programmatically |

## Key Bindings

All tagit buffers show their complete keybindings in an on-screen help overlay by pressing `?`. This is the primary reference — the overlay is always up-to-date with the code.

- **Status buffer** (`tagit.status()`): staging, navigation, conflict resolution, command menus
- **Log buffer** (`tagit.log()`): cherry-pick, rebase interactive here, revert
- **Branch list** (`tagit.branch_list()`): switch, rename, set/unset upstream, delete, toggle remote view, show log
- **Stash list** (`tagit.stash_list()`): apply, pop, drop, show diff

### Transient Menus

tagit uses transient menus for multi-step operations. Each menu shows available keys and their actions in the status bar. Press an unbound key to exit.

- **Commit**: create a commit (optionally amending), stage updated tracked files then commit, reword the last commit, squash, stage updated tracked files then squash
- **Push**: push, force push (with confirmation), initial push with upstream
- **Fetch/Pull**: fetch origin, fetch all with prune, fetch all tags, pull with fast-forward only
- **Branch**: switch, create and switch, orphan, previous, rename, delete (local or remote), set/unset upstream, list local or remote branches
- **Stash**: push (with variants for keep-index, include-untracked, all, or staged), pop, apply, list stashes, clear all
- **Reset/Clean**: reload (fetch + reset @{upstream}), hard reset, drop last commit, undo last commit, hard reset to any ref, clean untracked, purge untracked and ignored
- **Cherry-pick**: pick a commit (by ref or from a branch), continue/abort/skip when a cherry-pick is in progress
- **Merge/Rebase**: merge a branch, interactive rebase; continue/abort/skip when a merge or rebase is in progress (also handles in-progress cherry-pick)

## Configuration

### Custom commit date

`tagit.git.commit_date` accepts `nil` (git's default, author's local time), a date string, or a function returning one. When set, both `GIT_AUTHOR_DATE` and `GIT_COMMITTER_DATE` are passed to every git command that creates a commit.

Default (UTC):

```lua
require('tagit').git.commit_date = function()
  return os.date('!%Y-%m-%d %H:%M:%S +0000')
end
```

To use git's default (author's local time):

```lua
require('tagit').git.commit_date = nil
```

Example: local time with correct timezone offset:

```lua
require('tagit').git.commit_date = function()
  local now = os.time()
  local local_t = os.date('*t', now)
  local utc_t = os.date('!*t', now)
  local offset = os.difftime(os.time(local_t), os.time(utc_t))
  local sign = offset >= 0 and '+' or '-'
  local hours = math.floor(math.abs(offset) / 3600)
  local mins = math.floor((math.abs(offset) % 3600) / 60)
  return os.date('!%Y-%m-%d %H:%M:%S ', now) .. sign .. string.format('%02d%02d', hours, mins)
end
```
