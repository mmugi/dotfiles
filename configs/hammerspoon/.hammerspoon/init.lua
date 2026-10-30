-- Load EmmyLua.spoon if it is installed. It generates Hammerspoon type stubs for
-- lua-language-server in ~/.hammerspoon/Spoons/EmmyLua.spoon/annotations.
-- Nothing happens when it is not installed.
--
-- To install:
--   1. Unzip https://github.com/Hammerspoon/Spoons/raw/master/Spoons/EmmyLua.spoon.zip
--      and double-click EmmyLua.spoon (Hammerspoon moves it to ~/.hammerspoon/Spoons/).
--   2. Add ~/.hammerspoon/Spoons/EmmyLua.spoon/annotations to workspace.library
--      in the lua-language-server settings. .luarc.json next to this file does it:
--
--        {
--          "runtime.version": "<Lua version of Hammerspoon>",
--          "workspace.library": ["~/.hammerspoon/Spoons/EmmyLua.spoon/annotations"]
--        }
--
--      Replace the placeholder with the value of _VERSION in the Hammerspoon console
--      (e.g. "Lua 5.4").
--   3. Reload Config in Hammerspoon to generate the stubs, then reopen this file
--      (or restart lua-language-server) so that the stubs are read.
if hs.spoons.isInstalled('EmmyLua') then hs.loadSpoon('EmmyLua') end

---@class FrameEntry
---@field restoreTo hs.geometry
---@field last hs.geometry?

---@class Track
---@field start number
---@field size number

---画面に対する割合 (0〜1) で表した水平方向の範囲 (位置 x と幅 w)
---@class HorizontalSpan
---@field x number
---@field w number

---画面に対する割合 (0〜1) で表した垂直方向の範囲 (位置 y と高さ h)
---@class VerticalSpan
---@field y number
---@field h number

---画面に対する割合 (0〜1) で表した位置と大きさ (Hammerspoon の unit rect)
---@class UnitRect
---@field x number
---@field y number
---@field w number
---@field h number
---
---@class GridLayout
---@field type 'grid'
---@field cols number[]
---@field rows number[]

---@class SpansLayout
---@field type 'spans'
---@field horizontalSpans HorizontalSpan[]

---@class RectsLayout
---@field type 'rects'
---@field rects UnitRect[]

---@alias Layout GridLayout|SpansLayout|RectsLayout
---@alias Direction 'left'|'right'|'up'|'down'
---@alias Mover fun(win: hs.window, direction: Direction?, entry: FrameEntry?)

-- ---- appearance ------------------------------------------------------------

hs.window.animationDuration = 0

-- mmerr cyan #59fbff
-- 背景は cyan から計算 (コントラスト比 3.5:1)
hs.alert.defaultStyle.strokeWidth = 2
hs.alert.defaultStyle.strokeColor = { hex = '#59fbff' }
hs.alert.defaultStyle.radius = 2
hs.alert.defaultStyle.fillColor = { hex = '#2f8672', alpha = 0.5 }
hs.alert.defaultStyle.textSize = 20
hs.alert.defaultStyle.textColor = { hex = '#59fbff' }

local prefixModeAlertText = 'Awaiting key...'

-- ---- window actions --------------------------------------------------------

-- restore 用のフレームの記録。windowAction 経由で更新される。
--
-- frames[<window id>] = {
--   restoreTo = <移動前のフレーム>,
--   last      = <最後の移動後のフレーム>,
-- }
---@type table<integer, FrameEntry>
local frames = {}

-- フォーカス中のウィンドウと、そのフレームの記録を fn に渡す関数を返す。
-- フォーカス中のウィンドウのフレームが last と違う場合は、手で動かされたとみなして
-- 今のフレームを新しい restoreTo に記録する。
---@param fn fun(win: hs.window, entry: FrameEntry)
---@return fun()
local function windowAction(fn)
  return function()
    local win = hs.window.focusedWindow()
    local id = win and win:id()
    if not id then return end
    local frame = win:frame()
    local entry = frames[id]
    if not entry or not frame:equals(entry.last) then
      entry = { restoreTo = frame }
      frames[id] = entry
    end
    fn(win, entry)
    entry.last = win:frame()
  end
end

---@param win hs.window
---@param entry FrameEntry
local function restore(win, entry)
  win:setFrame(entry.restoreTo)
end

---@param screen hs.screen
---@param direction Direction?
---@return hs.screen
local function nextScreen(screen, direction)
  local toward = direction == 'right' and 'toEast' or 'toWest'
  local opposite = direction == 'right' and 'toWest' or 'toEast'
  local neighbor = screen[toward](screen)
  if neighbor then return neighbor end
  while screen[opposite](screen) do screen = screen[opposite](screen) end
  return screen
end

---@param win hs.window
---@param direction Direction
---@param entry FrameEntry
local function snap(win, direction, entry)
  if direction == 'up' then return win:maximize() end
  if direction == 'down' then return restore(win, entry) end
  local toward = direction == 'left' and hs.layout.left50 or hs.layout.right50
  local opposite = direction == 'left' and hs.layout.right50 or hs.layout.left50
  local screen = win:screen()
  local before = win:frame()
  win:setFrame(screen:fromUnitRect(toward))
  local after = win:frame()
  if not after:equals(before) then return end
  win:setFrame(nextScreen(screen, direction):fromUnitRect(opposite))
end

local terminalSize = { w = 1100, h = 850 }

---@param win hs.window
local function resizeToTerminal(win)
  local frame = win:frame()
  frame.w, frame.h = terminalSize.w, terminalSize.h
  win:setFrameInScreenBounds(frame)
end

-- ---- layouts ---------------------------------------------------------------

-- プレフィックスモードの windowAction で使用する配置表。type で動かし方が決まる。
-- 共通して、左右キーで画面端を越えた場合は隣の画面の端へ移動する。
--   grid:  列の幅 (cols) と行の高さ (rows) を画面に対する割合で並べる。
--          矢印キーで隣のセルへ移動する。
--   spans: horizontalSpans に水平方向の位置 (x) と幅 (w) を画面に対する割合で並べる。
--          左右キーで順に巡り、上下キーで高さを調整する。
--   rects: rects に位置と大きさ (x, y, w, h) を画面に対する割合で並べる。
--          左右キーで順に巡り、上キーで最大化、下キーで restore する。
---@type table<string, Layout>
local layouts = {
  maximized = { type = 'spans', horizontalSpans = { { x = 0, w = 1 } } },
  sides = { type = 'spans', horizontalSpans = {
    { x = 0, w = 0.35 },
    { x = 0, w = 0.5 },
    { x = 0, w = 0.65 },
    { x = 0.35, w = 0.65 },
    { x = 0.5, w = 0.5 },
    { x = 0.65, w = 0.35 },
  } },
  thirds = { type = 'spans', horizontalSpans = {
    { x = 0, w = 1 / 3 },
    { x = 1 / 3, w = 1 / 3 },
    { x = 2 / 3, w = 1 / 3 },
  } },
  quarters = { type = 'grid', cols = { 0.5, 0.5 }, rows = { 0.5, 0.5 } },
}

---@type Layout
local currentLayout

---@type { x: integer, y: integer }
local stay = { x = 0, y = 0 }
---@type table<Direction, { x: integer, y: integer }>
local indexOffsets = {
  left = { x = -1, y = 0 },
  right = { x = 1, y = 0 },
  up = { x = 0, y = -1 },
  down = { x = 0, y = 1 },
}

-- 画面に対する始まり (start) と大きさ (size) を持つトラックの配列を ratios から生成する。
-- 例えば ratios = { 0.2, 0.3, 0.5 } なら、20% / 30% / 50% に分けて start, size を計算する。
-- (cols でのイメージ。rows の場合も同じで上から順に並ぶ。)
--
--   0         0.2            0.5                      1  ← start
--   ┌─────────┬──────────────┬────────────────────────┐
--   │ idx 1   │ idx 2        │ idx 3                  │
--   │         │              │                        │
--   └─────────┴──────────────┴────────────────────────┘
--   ├── 0.2 ──┼──── 0.3 ─────┼───────── 0.5 ──────────┤  ← size
--
-- → { { start = 0, size = 0.2 }, { start = 0.2, size = 0.3 }, { start = 0.5, size = 0.5 } }
---@param ratios number[]
---@return Track[]
local function tracksOf(ratios)
  local tracks, start = {}, 0
  for i, ratio in ipairs(ratios) do
    tracks[i] = { start = start, size = ratio }
    start = start + ratio
  end
  return tracks
end

-- coordinate (0-1) がどのトラック内かをインデックスで返す。
---@param tracks Track[]
---@param coordinate number
---@return integer
local function trackIndexAt(tracks, coordinate)
  for i, track in ipairs(tracks) do
    if coordinate < track.start + track.size then return i end
  end
  return #tracks
end

---@type Mover
local function moveInGrid(win, direction)
  local offset = indexOffsets[direction] or stay
  local cols, rows = tracksOf(currentLayout.cols), tracksOf(currentLayout.rows)
  local screen = win:screen()
  local unit = screen:toUnitRect(win:frame()) --[[@as UnitRect]]
  local centerX = unit.x + unit.w / 2
  local centerY = unit.y + unit.h / 2
  local destColIndex = trackIndexAt(cols, centerX) + offset.x
  local destRowIndex = trackIndexAt(rows, centerY) + offset.y
  if destColIndex < 1 or destColIndex > #cols then
    screen = nextScreen(screen, direction)
    destColIndex = direction == 'right' and 1 or #cols
  end
  destRowIndex = math.max(1, math.min(#rows, destRowIndex))
  local destCol, destRow = cols[destColIndex], rows[destRowIndex]
  win:setFrame(screen:fromUnitRect({
    x = destCol.start,
    y = destRow.start,
    w = destCol.size,
    h = destRow.size,
  }))
end

-- placement と unit の中心どうしの水平方向の距離。
---@param placement HorizontalSpan
---@param unit UnitRect
---@return number
local function horizontalDistance(placement, unit)
  return math.abs((placement.x + placement.w / 2) - (unit.x + unit.w / 2))
end

-- placement と unit の中心どうしの距離。
---@param placement UnitRect
---@param unit UnitRect
---@return number
local function centerDistance(placement, unit)
  local dx = (placement.x + placement.w / 2) - (unit.x + unit.w / 2)
  local dy = (placement.y + placement.h / 2) - (unit.y + unit.h / 2)
  return math.sqrt(dx * dx + dy * dy)
end

-- placements のうち、今の unit に一番近い direction 方向の screen と placement を返す。
-- 距離は measureDistance(placement, unit) で測る。
---@generic T
---@param screen hs.screen
---@param unit UnitRect
---@param placements T[]
---@param measureDistance fun(placement: T, unit: UnitRect): number
---@param direction Direction?
---@return hs.screen screen
---@return T placement
local function nextPlacement(screen, unit, placements, measureDistance, direction)
  local offset = indexOffsets[direction] or stay
  local nearest, nearestDistance
  for i, placement in ipairs(placements) do
    local distance = measureDistance(placement, unit)
    if not nearest or distance < nearestDistance then
      nearest = i
      nearestDistance = distance
    end
  end
  local index = nearest + offset.x
  if index < 1 or index > #placements then
    screen = nextScreen(screen, direction)
    index = direction == 'right' and 1 or #placements
  end
  return screen, placements[index]
end

---@type VerticalSpan
local topHalf = { y = 0, h = 0.5 }
---@type VerticalSpan
local bottomHalf = { y = 0.5, h = 0.5 }
---@type VerticalSpan
local fullHeight = { y = 0, h = 1 }

-- 今の unit から direction 方向へ移動するときの垂直方向の span を返す。
-- direction が上下の場合、それぞれ topHalf, bottomHalf。すでに半分の状態で反対方向なら fullHeight。
-- direction が左右か nil の場合、今が半分ならそのまま、そうでなければ fullHeight。
---@param unit UnitRect
---@param direction Direction?
---@return VerticalSpan
local function nextVerticalSpan(unit, direction)
  local half
  if math.abs(unit.h - 0.5) <= 0.1 then
    half = unit.y + unit.h / 2 < 0.5 and topHalf or bottomHalf
  end
  if direction ~= 'up' and direction ~= 'down' then return half or fullHeight end
  local toward = direction == 'up' and topHalf or bottomHalf
  if half and half ~= toward then return fullHeight end
  return toward
end

---@type Mover
local function moveInSpans(win, direction)
  local screen = win:screen()
  local unit = screen:toUnitRect(win:frame()) --[[@as UnitRect]]
  local horizontalSpans = currentLayout.horizontalSpans
  local destScreen, horizontalSpan =
    nextPlacement(screen, unit, horizontalSpans, horizontalDistance, direction)
  local verticalSpan = nextVerticalSpan(unit, direction)
  win:setFrame(destScreen:fromUnitRect({
    x = horizontalSpan.x,
    y = verticalSpan.y,
    w = horizontalSpan.w,
    h = verticalSpan.h,
  }))
end

---@type Mover
local function moveInRects(win, direction, entry)
  if direction == 'up' or direction == 'down' then return snap(win, direction, entry) end
  local screen = win:screen()
  local unit = screen:toUnitRect(win:frame()) --[[@as UnitRect]]
  local rects = currentLayout.rects
  local destScreen, rect = nextPlacement(screen, unit, rects, centerDistance, direction)
  win:setFrame(destScreen:fromUnitRect(rect))
end

---@type table<string, Mover>
local movers = {
  grid = moveInGrid,
  spans = moveInSpans,
  rects = moveInRects
}

---@type Mover
local function moveInLayout(win, direction, entry)
  movers[currentLayout.type](win, direction, entry)
end

---@param win hs.window
---@param selected Layout
local function selectLayout(win, selected)
  currentLayout = selected
  moveInLayout(win)
end

-- ---- key bindings ----------------------------------------------------------

hs.hotkey.bind({ 'cmd' }, 'left', windowAction(function(win, entry) snap(win, 'left', entry) end))
hs.hotkey.bind({ 'cmd' }, 'right', windowAction(function(win, entry) snap(win, 'right', entry) end))
hs.hotkey.bind({ 'cmd' }, 'up', windowAction(function(win, entry) snap(win, 'up', entry) end))
hs.hotkey.bind({ 'cmd' }, 'down', windowAction(function(win, entry) snap(win, 'down', entry) end))

-- ---- prefix mode -----------------------------------------------------------

local prefixMode = hs.hotkey.modal.new()

-- initialize
function prefixMode:entered()
  currentLayout = layouts.sides
  hs.alert.show(prefixModeAlertText, true)
end

-- finalize
function prefixMode:exited()
  hs.alert.closeAll()
end

-- enter prefix mode
hs.hotkey.bind({ 'ctrl', 'cmd' }, 'a', function() prefixMode:enter() end)

-- exit prefix mode
prefixMode:bind({ 'ctrl', 'cmd' }, 'a', function() prefixMode:exit() end)
prefixMode:bind({}, 'escape', function() prefixMode:exit() end)

prefixMode:bind({}, '1', windowAction(function(win) selectLayout(win, layouts.maximized) end))
prefixMode:bind({}, '2', windowAction(function(win) selectLayout(win, layouts.sides) end))
prefixMode:bind({}, '3', windowAction(function(win) selectLayout(win, layouts.thirds) end))
prefixMode:bind({}, '4', windowAction(function(win) selectLayout(win, layouts.quarters) end))

---@type table<string, Direction>
local moveKeys = {
  left = 'left', right = 'right', up = 'up', down = 'down',
  h = 'left', l = 'right', k = 'up', j = 'down'
}
for key, direction in pairs(moveKeys) do
  prefixMode:bind({}, key, windowAction(function(win, entry)
    moveInLayout(win, direction, entry)
  end))
end

prefixMode:bind({}, 'c', function()
  windowAction(resizeToTerminal)()
  prefixMode:exit()
end)
