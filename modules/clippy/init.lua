local M = {}

M.max_size = 60

-- each entry: { content = "...", snippet = "..." }
local entries = {}

function M.add(input)
  if not input then return end

  local content = tostring(input)
  if content == '' then return end
  local snippet = content:gsub('[\r\n]+', '')
  snippet = snippet:gsub('%s+', ' ')
  snippet = snippet:sub(1, 200)

  -- dedupe by content
  for i = #entries, 1, -1 do
    if entries[i].content == content then
      table.remove(entries, i)
      break
    end
  end

  table.insert(entries, 1, { content = content, snippet = snippet })

  if #entries > M.max_size then table.remove(entries) end
end

function M.copy()
  buffer:copy_allow_line()
  M.add(ui.get_clipboard_text())
end

function M.cut()
  buffer:cut_allow_line()
  M.add(ui.get_clipboard_text())
end

local function get_items()
  local items = {}
  for i = 1, #entries do
    items[i] = entries[i].snippet
  end
  return items
end

function M.show(remove)
  if #entries == 0 then
    ui.statusbar_text = 'clippy has no content'
    return
  end

  local items = get_items()
  local index = ui.dialogs.list({
    title = 'clippy ' .. (remove and 'REMOVE' or 'INSERT'),
    items = items,
  })

  if not index then return end

  if not remove then
    buffer:begin_undo_action()
    for i = buffer.selections, 1, -1 do
      local s, e = buffer.selection_n_start[i], buffer.selection_n_end[i]
      buffer:set_target_range(s, e)
      buffer:replace_target(entries[index].content)
    end
    buffer:end_undo_action()
  else
    local button = ui.dialogs.message({
      title = "It looks like you're trying to delete a clippy entry",
      text = 'Are you sure?',
      icon = 'dialog-question',
      button1 = 'Yes',
      button2 = 'No',
    })
    if button == 1 then table.remove(entries, index) end
  end
end

function M.remove()
  M.show(true)
end

function M.clear()
  local button = ui.dialogs.message({
    title = "It looks like you're trying to clear the clippy cache",
    text = 'Are you sure?',
    icon = 'dialog-question',
    button1 = 'Yes',
    button2 = 'No',
  })
  if button == 1 then entries = {} end
end

return M
