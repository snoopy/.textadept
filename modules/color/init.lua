local M = {}

function M.rgb2bgr(rgb)
  local r, g, b = rgb:match('(..)(..)(..)')
  return string.format('0x%02X%02X%02X', tonumber(b, 16), tonumber(g, 16), tonumber(r, 16))
end

return M
