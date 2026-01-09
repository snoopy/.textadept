local M = {}

local formatters = {
  ['cpp'] = 'clang-format -i -style=file -fallback-style=none',
  ['python'] = 'ruff format --line-length 120',
  ['lua'] = 'stylua'
    .. ' --syntax lua54'
    .. ' --indent-width 2'
    .. ' --indent-type Spaces'
    .. ' --quote-style AutoPreferSingle'
    .. ' --collapse-simple-statement ConditionalOnly',
  ['rust'] = 'rustfmt',
}

M.on_save = {}
for k, _ in pairs(formatters) do
  M.on_save[k] = true
end

function M.toggle_on_save()
  local lang = buffer:get_lexer(true)
  if not lang then return end
  if M.on_save[lang] == nil then return end
  M.on_save[lang] = not M.on_save[lang]
  ui.statusbar_text = 'Format on save for "' .. lang .. '" is now: ' .. (M.on_save[lang] and 'ON' or 'OFF')
end

function M.run(filename)
  local lang = buffer:get_lexer(true)
  if not filename or not lang or not formatters[lang] then return end
  local proc = os.spawn(formatters[lang] .. ' "' .. filename .. '" 2>&1')
  if not proc then
    ui.statusbar_text = 'ERROR - failed running formatter for: ' .. lang
    return
  end
  local stdout = proc:read('a')
  if stdout:match('error') then
    ui.print(stdout)
    return
  end
  buffer:reload()
end

events.connect(events.FILE_AFTER_SAVE, function(filename)
  if M.on_save[buffer.lexer_language] then M.run(filename) end
end)

return M
