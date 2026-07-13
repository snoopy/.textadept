-- The tagit commit message buffer.
--
-- Opens an editable scratch buffer pre-filled with a template.
-- Confirming (ctrl+enter) strips comment lines, commits, closes the buffer and refreshes the status buffer.
-- Canceling (ctrl+escape) discards it.

local git = require('tagit.git')
local common = require('tagit.common')
local transient = require('tagit.transient')

local M = {}

local KEYS_MODE = 'tagit_commit'

-- Build the commit buffer template, including a commented status summary.
local function template(root, amend)
  local lines = {
    '',
    '',
    '# Please enter the commit message for your changes. Lines starting with',
    "# '#' will be ignored, and an empty message aborts the commit.",
    '# Confirm with ctrl+enter, cancel with ctrl+escape.',
    '#',
  }
  if amend then
    local msg, code = git.run('log -1 --format=%B', root)
    if msg and code == 0 and #msg > 0 then
      lines[1] = common.trim(msg)
      lines[2] = ''
    end
    lines[#lines + 1] = '# This commit amends the previous commit.'
  end
  local summary = git.run('-c core.quotePath=false status --short --branch', root)
  if summary then
    for l in (summary .. '\n'):gmatch('(.-)\n') do
      if l ~= '' then lines[#lines + 1] = '# ' .. l end
    end
  end
  return table.concat(lines, '\n')
end

-- Strip comment and trailing-whitespace lines, returning the message body.
local function clean_message(text)
  local out = {}
  for l in (text .. '\n'):gmatch('(.-)\n') do
    if l:sub(1, 1) ~= '#' then out[#out + 1] = l end
  end
  local message = table.concat(out, '\n')
  return common.trim(message:gsub('^%s+', ''))
end

-- Activate the commit keys mode only while a commit buffer is current.
local function update_keys_mode()
  if buffer._tagit_commit then
    keys.mode = KEYS_MODE
  elseif keys.mode == KEYS_MODE then
    keys.mode = nil
  end
end
events.connect(events.BUFFER_AFTER_SWITCH, update_keys_mode)
events.connect(events.VIEW_AFTER_SWITCH, update_keys_mode)

---
-- Opens a commit message buffer for the current repository.
-- @param amend When true, the commit amends the previous commit.
function M.start(amend)
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  if amend then
    local _, code = git.run('rev-parse HEAD --quiet', root)
    if code ~= 0 then
      ui.statusbar_text = 'No commits to amend'
      return
    end
  end
  buffer.new()
  buffer._tagit_commit = { root = root, amend = amend }
  buffer:set_lexer('text')
  buffer:add_text(template(root, amend))
  buffer:goto_pos(buffer:position_from_line(1))
  buffer:set_save_point()
  keys.mode = KEYS_MODE
end

---
-- Squashes the current commit into the previous one by amending HEAD without editing the message.
function M.squash()
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  local out, code = git.commit_amend_no_edit(root)
  if code ~= 0 then
    ui.statusbar_text = 'squash failed: ' .. (out and common.trim(out) or '?')
    return
  end
  ui.statusbar_text = 'Commit squashed'
  common.refresh_status()
end

---
-- Finalizes the commit using the current buffer's contents.
function M.finish()
  local info = buffer._tagit_commit
  if not info then return end
  local message = clean_message(buffer:get_text())
  if message == '' then
    ui.statusbar_text = 'Aborting commit due to empty message'
    return
  end
  local out, code = git.commit(message, info.amend, info.root)
  if code ~= 0 then
    ui.statusbar_text = 'commit failed: ' .. (out and common.trim(out) or '?')
    return
  end
  buffer._tagit_commit = nil
  keys.mode = nil
  buffer:set_save_point()
  buffer:close(true)
  ui.statusbar_text = 'Commit created'
  common.refresh_status()
end

---
-- Cancels the commit and discards the buffer.
function M.cancel()
  if not buffer._tagit_commit then return end
  buffer._tagit_commit = nil
  keys.mode = nil
  buffer:set_save_point()
  buffer:close(true)
  ui.statusbar_text = 'Commit canceled'
end

-- Commit buffer key bindings.
keys[KEYS_MODE] = setmetatable({
  ['ctrl+\n'] = M.finish,
  ['ctrl+escape'] = M.cancel,
}, { __index = keys })

local function stage_all_and_commit()
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  local out, code = git.stage_updated(root)
  if code ~= 0 then
    ui.statusbar_text = 'stage all failed: ' .. (out and common.trim(out) or '?')
    return
  end
  M.start(false)
end

local function stage_all_and_squash()
  local root = common.root()
  if not root then
    ui.statusbar_text = 'Not a git repository'
    return
  end
  local out, code = git.stage_updated(root)
  if code ~= 0 then
    ui.statusbar_text = 'stage all failed: ' .. (out and common.trim(out) or '?')
    return
  end
  local out2, code2 = git.commit_amend_no_edit(root)
  if code2 ~= 0 then
    ui.statusbar_text = 'squash failed: ' .. (out2 and common.trim(out2) or '?')
    return
  end
  ui.statusbar_text = 'Commit squashed'
  common.refresh_status()
end

---
-- Opens the commit transient menu
function M.menu()
  transient.open('Commit', {
    {
      key = 'c',
      help = 'commit',
      action = function()
        M.start(false)
      end,
    },
    {
      key = 'C',
      help = 'stage all updated and commit',
      action = stage_all_and_commit,
    },
    {
      key = 'r',
      help = 'reword last commit',
      action = function()
        M.start(true)
      end,
    },
    {
      key = 's',
      help = 'squash',
      action = M.squash,
    },
    {
      key = 'S',
      help = 'stage all updated and squash',
      action = stage_all_and_squash,
    },
  })
end

return M
