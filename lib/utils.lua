--[[
  lib/utils.lua — Các hàm tiện ích dùng chung cho script tự động hoá.

  Tự động nhận diện môi trường và dùng đúng API:
    - XXTouch / XXTouch Elite : touch.on/move/off, screen.get_color, sys.msleep...
    - AutoTouch               : touchDown/Move/Up, getColor, usleep...

  Nhờ vậy `fishing.lua`, `config.lua`, `calibrate.lua` KHÔNG cần sửa khi
  chuyển giữa hai ứng dụng. Toạ độ trong config canh theo 1080x1920 và được
  tự scale theo độ phân giải máy thực tế.
]]

local Utils = {}

-- ==========================================================================
-- LỚP NỀN (BACKEND) — bọc API của XXTouch / AutoTouch về một giao diện chung
-- ==========================================================================
local BE = {}

local hasXXTouch  = (type(touch) == "table" and type(touch.on) == "function")
local hasAutoTouch = (type(touchDown) == "function")

if hasXXTouch then
  BE.name = "XXTouch"
elseif hasAutoTouch then
  BE.name = "AutoTouch"
else
  BE.name = "unknown"
end

-- ----- Chạm: down / move / up (một ngón, đủ cho câu cá) --------------------
if hasXXTouch then
  BE.down = function(x, y) touch.on(x, y) end
  BE.move = function(x, y) touch.move(x, y) end
  BE.up   = function(x, y) touch.off(x, y) end
elseif hasAutoTouch then
  local FID = 1
  BE.down = function(x, y) touchDown(FID, x, y) end
  BE.move = function(x, y) touchMove(FID, x, y) end
  BE.up   = function(x, y) touchUp(FID, x, y) end
else
  BE.down = function() end
  BE.move = function() end
  BE.up   = function() end
end

-- ----- Nghỉ theo mili-giây -------------------------------------------------
if type(sys) == "table" and type(sys.msleep) == "function" then
  BE.sleep = function(ms) sys.msleep(math.floor(ms)) end        -- XXTouch
elseif type(mSleep) == "function" then
  BE.sleep = function(ms) mSleep(math.floor(ms)) end            -- biến thể TS
elseif type(usleep) == "function" then
  BE.sleep = function(ms) usleep(math.floor(ms * 1000)) end     -- AutoTouch
else
  BE.sleep = function(ms)                                       -- fallback bận
    local target = (os.clock and os.clock() or 0) + ms / 1000
    while os.clock and os.clock() < target do end
  end
end

-- ----- Đọc màu tại (x, y) → trả về số nguyên 0xRRGGBB ----------------------
if type(screen) == "table" and type(screen.get_color) == "function" then
  BE.getColor = function(x, y)                                  -- XXTouch
    local a, b, c = screen.get_color(x, y)
    if b ~= nil and c ~= nil then
      return a * 0x10000 + b * 0x100 + c   -- một số bản trả về r,g,b riêng
    end
    return a                                -- bản khác trả về sẵn 0xRRGGBB
  end
elseif type(getColor) == "function" then
  BE.getColor = function(x, y) return getColor(x, y) end        -- AutoTouch
else
  BE.getColor = function() return nil end
end

-- ----- Kích thước màn hình -------------------------------------------------
if type(screen) == "table" and type(screen.size) == "function" then
  BE.screenSize = function() return screen.size() end           -- XXTouch
elseif type(getScreenResolution) == "function" then
  BE.screenSize = function() return getScreenResolution() end   -- AutoTouch
else
  BE.screenSize = function() return nil, nil end
end

-- ----- Thông báo & log -----------------------------------------------------
BE.toast = function(msg)
  if type(sys) == "table" and type(sys.toast) == "function" then
    sys.toast(msg)                                              -- XXTouch
  elseif type(toast) == "function" then
    toast(msg)                                                  -- AutoTouch
  end
end

BE.log = function(msg)
  if type(nLog) == "function" then nLog(msg)                    -- XXTouch
  elseif type(sys) == "table" and type(sys.log) == "function" then sys.log(msg)
  elseif type(log) == "function" then log(msg)                  -- AutoTouch
  elseif type(print) == "function" then print(msg) end
end

Utils.backendName = BE.name

-- ==========================================================================
-- LOG & THÔNG BÁO
-- ==========================================================================
Utils.verbose = false

function Utils.logMsg(msg)
  if Utils.verbose then BE.log("[Bot] " .. tostring(msg)) end
end

function Utils.notify(msg)
  BE.toast(tostring(msg))
  Utils.logMsg(msg)
end

-- ==========================================================================
-- THỜI GIAN
-- ==========================================================================
function Utils.sleepMs(ms)
  BE.sleep(ms)
end

function Utils.nowMs()
  if type(os) == "table" and type(os.clock) == "function" then
    return os.clock() * 1000
  end
  return 0
end

-- ==========================================================================
-- SCALE TOẠ ĐỘ THEO ĐỘ PHÂN GIẢI
-- ==========================================================================
Utils.scaleX = 1.0
Utils.scaleY = 1.0

function Utils.setScale(baseW, baseH)
  local w, h = baseW, baseH
  local rw, rh = BE.screenSize()
  if rw and rh and rw > 0 and rh > 0 then
    -- Canh theo hướng portrait: cạnh ngắn = width
    w = math.min(rw, rh)
    h = math.max(rw, rh)
  end
  Utils.scaleX = w / baseW
  Utils.scaleY = h / baseH
  Utils.logMsg(string.format("Backend=%s  Scale=(%.3f, %.3f)",
    BE.name, Utils.scaleX, Utils.scaleY))
end

local function sx(x) return math.floor(x * Utils.scaleX + 0.5) end
local function sy(y) return math.floor(y * Utils.scaleY + 0.5) end
Utils.sx = sx
Utils.sy = sy

-- ==========================================================================
-- TAP / SWIPE
-- ==========================================================================
function Utils.tap(x, y, holdMs)
  holdMs = holdMs or 30
  local px, py = sx(x), sy(y)
  BE.down(px, py)
  Utils.sleepMs(holdMs)
  BE.up(px, py)
end

function Utils.tapN(x, y, times, intervalMs, holdMs)
  times = times or 1
  intervalMs = intervalMs or 60
  for i = 1, times do
    Utils.tap(x, y, holdMs)
    if i < times then Utils.sleepMs(intervalMs) end
  end
end

function Utils.swipe(x1, y1, x2, y2, durationMs, steps)
  steps = steps or 12
  durationMs = durationMs or 200
  local ax1, ay1 = sx(x1), sy(y1)
  local ax2, ay2 = sx(x2), sy(y2)
  local stepSleep = durationMs / steps

  BE.down(ax1, ay1)
  Utils.sleepMs(stepSleep)
  for i = 1, steps do
    local t = i / steps
    local mx = math.floor(ax1 + (ax2 - ax1) * t + 0.5)
    local my = math.floor(ay1 + (ay2 - ay1) * t + 0.5)
    BE.move(mx, my)
    Utils.sleepMs(stepSleep)
  end
  BE.up(ax2, ay2)
end

-- ==========================================================================
-- ĐỌC & SO KHỚP MÀU
-- ==========================================================================
local function rgb(color)
  local r = math.floor(color / 0x10000) % 0x100
  local g = math.floor(color / 0x100) % 0x100
  local b = color % 0x100
  return r, g, b
end

function Utils.getColorAt(x, y)
  return BE.getColor(sx(x), sy(y))
end

function Utils.colorMatch(c1, c2, tolerance)
  if not c1 or not c2 then return false end
  tolerance = tolerance or 20
  local r1, g1, b1 = rgb(c1)
  local r2, g2, b2 = rgb(c2)
  return math.abs(r1 - r2) <= tolerance
     and math.abs(g1 - g2) <= tolerance
     and math.abs(b1 - b2) <= tolerance
end

function Utils.anchorActive(anchor)
  if not anchor then return false end
  local c = Utils.getColorAt(anchor.x, anchor.y)
  return Utils.colorMatch(c, anchor.color, anchor.tolerance)
end

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
