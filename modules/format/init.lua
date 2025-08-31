local M = {}

M.on_save = {}

local formatters = {
  ['cpp'] = 'clang-format -i -style=file -fallback-style=none',
  ['python'] = 'black -l 120',
  ['lua'] = 'stylua'
    .. ' --indent-width 2'
    .. ' --indent-type Spaces'
    .. ' --quote-style AutoPreferSingle'
    .. ' --collapse-simple-statement ConditionalOnly',
  ['rust'] = 'rustfmt',
}

function M.toggle_on_save()
  local lang = buffer:get_lexer(true)
  if not lang then return end
  if M.on_save[lang] == nil then return end
  M.on_save[lang] = not M.on_save[lang]
  ui.statusbar_text = 'Format on save for "' .. lang .. '" is now: ' .. (M.on_save[lang] and 'ON' or 'OFF')
end

function M.run(filename)
  local lang = buffer:get_lexer(true)
  if not filename or not lang then return end
  if not formatters[lang] then return end
  local proc = os.spawn(formatters[lang] .. ' "' .. filename .. '"')
  if not proc then return end
  proc:wait()
  buffer:reload()
end

events.connect(events.FILE_AFTER_SAVE, function(filename)
  if M.on_save[buffer.lexer_language] then M.run(filename) end
end)

return M
