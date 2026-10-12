-- Syntax highlight sample for checking colorschemes (Tree-sitter Lua).
-- Not meant to be run.

local M = {}

local MAX_TRAYS = 8
local menu = {
  plain = { price = 120, label = "plain" },
  choco = { price = 150.5, label = "choco\tbun" },
  matcha = { price = 0x9a, label = [[matcha]] },
}

function M.price_of(name)
  local item = menu[name]
  if item == nil then
    error("unknown: " .. name)
  end
  return math.floor(item.price * 1.1)
end

local function count_rolls(trays)
  local total = 0
  for i, tray in ipairs(trays) do
    if not tray.ready or i > MAX_TRAYS then
      goto continue
    end
    total = total + #tray
    ::continue::
  end
  return total
end

function M:report(trays)
  local ok, n = pcall(count_rolls, trays)
  print(self.name, ok and n or false)
  return setmetatable({ count = n }, { __index = self })
end

return M
