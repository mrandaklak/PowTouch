--[[
  lib/utils.lua — Các hàm tiện ích dùng chung cho script AutoTouch
  Bao bọc (wrap) các API AutoTouch để tap/swipe/đọc màu ổn định hơn,
  đồng thời tự động scale toạ độ theo độ phân giải thực tế của máy.
]]

local Utils = {}

-- ----- Log & thông báo -----------------------------------------------------

Utils.verbose = false

function Utils.logMsg(msg)
  if Utils.verbose and type(log) == "function" then
    log("[AceFishing] " .. tostring(msg))
  end
end

function Utils.notify(msg)
  if type(toast) == "function" then
    toast(tostring(msg))
  end
  Utils.logMsg(msg)
end

-- ----- Thời gian -----------------------------------------------------------

-- Nghỉ theo mili-giây (AutoTouch usleep tính bằng micro-giây)
function Utils.sleepMs(ms)
  usleep(math.floor(ms * 1000))
end

-- Trả về mốc thời gian hiện tại (mili-giây) nếu môi trường hỗ trợ.
function Utils.nowMs()
  if type(os) == "table" and type(os.clock) == "function" then
    return os.clock() * 1000
  end
  return 0
end

-- ----- Scale toạ độ theo độ phân giải ---------------------------------------

-- baseW/baseH: độ phân giải mà toạ độ trong config được canh theo.
-- Utils.setScale sẽ tính hệ số scale dựa trên màn hình thực tế.
Utils.scaleX = 1.0
Utils.scaleY = 1.0

function Utils.setScale(baseW, baseH)
  local w, h = baseW, baseH
  if type(getScreenResolution) == "function" then
    local rw, rh = getScreenResolution()
    if rw and rh and rw > 0 and rh > 0 then
      -- Canh theo hướng portrait: cạnh ngắn = width
      w = math.min(rw, rh)
      h = math.max(rw, rh)
    end
  end
  Utils.scaleX = w / baseW
  Utils.scaleY = h / baseH
  Utils.logMsg(string.format("Scale = (%.3f, %.3f)", Utils.scaleX, Utils.scaleY))
end

local function sx(x) return math.floor(x * Utils.scaleX + 0.5) end
local function sy(y) return math.floor(y * Utils.scaleY + 0.5) end
Utils.sx = sx
Utils.sy = sy

-- ----- Tap / Swipe ----------------------------------------------------------

local FINGER_TAP   = 3
local FINGER_SWIPE = 5

-- Một lần chạm dứt khoát tại (x, y)
function Utils.tap(x, y, holdMs)
  holdMs = holdMs or 30
  local px, py = sx(x), sy(y)
  touchDown(FINGER_TAP, px, py)
  Utils.sleepMs(holdMs)
  touchUp(FINGER_TAP, px, py)
end

-- Tap nhiều lần với khoảng nghỉ giữa các lần
function Utils.tapN(x, y, times, intervalMs, holdMs)
  times = times or 1
  intervalMs = intervalMs or 60
  for i = 1, times do
    Utils.tap(x, y, holdMs)
    if i < times then Utils.sleepMs(intervalMs) end
  end
end

-- Vuốt mượt từ (x1,y1) tới (x2,y2) trong durationMs
function Utils.swipe(x1, y1, x2, y2, durationMs, steps)
  steps = steps or 12
  durationMs = durationMs or 200
  local ax1, ay1 = sx(x1), sy(y1)
  local ax2, ay2 = sx(x2), sy(y2)
  local stepSleep = durationMs / steps

  touchDown(FINGER_SWIPE, ax1, ay1)
  Utils.sleepMs(stepSleep)
  for i = 1, steps do
    local t = i / steps
    local mx = math.floor(ax1 + (ax2 - ax1) * t + 0.5)
    local my = math.floor(ay1 + (ay2 - ay1) * t + 0.5)
    touchMove(FINGER_SWIPE, mx, my)
    Utils.sleepMs(stepSleep)
  end
  touchUp(FINGER_SWIPE, ax2, ay2)
end

-- ----- Đọc & so khớp màu ----------------------------------------------------

-- Tách 1 màu 0xRRGGBB thành 3 kênh
local function rgb(color)
  local r = math.floor(color / 0x10000) % 0x100
  local g = math.floor(color / 0x100) % 0x100
  local b = color % 0x100
  return r, g, b
end

-- Đọc màu tại (x, y) theo toạ độ ĐÃ scale
function Utils.getColorAt(x, y)
  if type(getColor) ~= "function" then return nil end
  return getColor(sx(x), sy(y))
end

-- So khớp hai màu với sai số tolerance (khoảng cách từng kênh)
function Utils.colorMatch(c1, c2, tolerance)
  if not c1 or not c2 then return false end
  tolerance = tolerance or 20
  local r1, g1, b1 = rgb(c1)
  local r2, g2, b2 = rgb(c2)
  return math.abs(r1 - r2) <= tolerance
     and math.abs(g1 - g2) <= tolerance
     and math.abs(b1 - b2) <= tolerance
end

-- Kiểm tra một anchor {x, y, color, tolerance} có khớp trạng thái không
function Utils.anchorActive(anchor)
  if not anchor then return false end
  local c = Utils.getColorAt(anchor.x, anchor.y)
  return Utils.colorMatch(c, anchor.color, anchor.tolerance)
end

-- Chờ tới khi anchor khớp (hoặc hết timeout). Trả về true nếu khớp.
function Utils.waitForAnchor(anchor, timeoutMs, pollMs)
  timeoutMs = timeoutMs or 5000
  pollMs = pollMs or 50
  local waited = 0
  while waited < timeoutMs do
    if Utils.anchorActive(anchor) then return true end
    Utils.sleepMs(pollMs)
    waited = waited + pollMs
  end
  return false
end

return Utils
