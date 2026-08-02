--[[
  lib/utils.lua — Tiện ích + tương thích backend cho bot Ace Fishing.

  THIẾT KẾ THEO CƠ CHẾ AUTOTOUCH (không bắt chước AutoJS):
    - AutoTouch KHÔNG có kiểu "chụp vào RAM rồi images.pixel()". Muốn đọc nhiều
      điểm mà không gọi getColor lặp lại nhiều lần, dùng getColors({{x,y},...})
      — MỘT lời gọi native đọc cả danh sách, trả về bảng màu.
    - findColor/findColors KHÔNG có sai số màu (theo tài liệu), nên KHÔNG hợp để
      đo thanh lực gradient. Ta đọc điểm bằng getColors rồi TỰ so màu có sai số.

  Nguồn API: https://docs.autotouch.net/lua/
]]

local Utils = {}

-- ==========================================================================
-- BACKEND — bọc API AutoTouch / XXTouch về một giao diện chung
-- ==========================================================================
local BE = {}

local hasAutoTouch = (type(touchDown) == "function")
local hasXXTouch   = (type(touch) == "table" and type(touch.on) == "function")

if hasAutoTouch     then BE.name = "AutoTouch"
elseif hasXXTouch   then BE.name = "XXTouch"
else                     BE.name = "unknown" end

-- ----- Chạm: down / move / up (một ngón) ----------------------------------
if hasAutoTouch then
  local FID = 2
  BE.down = function(x, y) touchDown(FID, x, y) end
  BE.move = function(x, y) touchMove(FID, x, y) end
  BE.up   = function(x, y) touchUp(FID, x, y) end
elseif hasXXTouch then
  BE.down = function(x, y) touch.on(x, y) end
  BE.move = function(x, y) touch.move(x, y) end
  BE.up   = function(x, y) touch.off(x, y) end
else
  BE.down = function() end
  BE.move = function() end
  BE.up   = function() end
end

-- ----- Nghỉ theo mili-giây -------------------------------------------------
if type(usleep) == "function" then
  BE.sleep = function(ms) usleep(math.floor(ms * 1000)) end            -- AutoTouch
elseif type(sys) == "table" and type(sys.msleep) == "function" then
  BE.sleep = function(ms) sys.msleep(math.floor(ms)) end              -- XXTouch
elseif type(mSleep) == "function" then
  BE.sleep = function(ms) mSleep(math.floor(ms)) end
else
  BE.sleep = function(ms)
    local target = (os.clock and os.clock() or 0) + ms / 1000
    while os.clock and os.clock() < target do end
  end
end

-- ----- Đọc màu 1 điểm → số nguyên 0xRRGGBB --------------------------------
if type(getColor) == "function" then
  -- AutoTouch: getColor(x,y) trả về color (một số bản trả color,err — lấy cái đầu).
  BE.getColor1 = function(x, y) local c = getColor(x, y); return c end
elseif type(screen) == "table" and type(screen.get_color) == "function" then
  BE.getColor1 = function(x, y)                                        -- XXTouch
    local a, b, c = screen.get_color(x, y)
    if b ~= nil and c ~= nil then return a * 0x10000 + b * 0x100 + c end
    return a
  end
else
  BE.getColor1 = function() return nil end
end

-- ----- Đọc màu NHIỀU điểm trong 1 lời gọi (điểm đã ở PIXEL thật) -----------
-- points = { {x,y}, {x,y}, ... }  ->  trả về { color1, color2, ... }
if hasAutoTouch and type(getColors) == "function" then
  BE.getColors = function(points)
    local res = getColors(points)          -- native: 1 lời gọi, cả danh sách
    if type(res) == "table" then return res end
    -- phòng hờ bản trả (colors, err) mà res không phải table:
    local out = {}
    for i = 1, #points do out[i] = BE.getColor1(points[i][1], points[i][2]) end
    return out
  end
else
  -- XXTouch / unknown: chưa có batch tương đương -> đọc lẻ (XXTouch đọc từ snapshot
  -- nội bộ nên vẫn rẻ hơn AutoTouch getColor lặp).
  BE.getColors = function(points)
    local out = {}
    for i = 1, #points do out[i] = BE.getColor1(points[i][1], points[i][2]) end
    return out
  end
end

-- ----- Kích thước màn hình -------------------------------------------------
if type(getScreenResolution) == "function" then
  BE.screenSize = function() return getScreenResolution() end          -- AutoTouch
elseif type(screen) == "table" and type(screen.size) == "function" then
  BE.screenSize = function() return screen.size() end                  -- XXTouch
else
  BE.screenSize = function() return nil, nil end
end

-- ----- Thông báo & log -----------------------------------------------------
BE.toast = function(msg)
  if type(toast) == "function" then toast(msg)
  elseif type(sys) == "table" and type(sys.toast) == "function" then sys.toast(msg) end
end
BE.log = function(msg)
  if type(log) == "function" then log(msg)
  elseif type(nLog) == "function" then nLog(msg)
  elseif type(sys) == "table" and type(sys.log) == "function" then sys.log(msg)
  elseif type(print) == "function" then print(msg) end
end

Utils.backendName = BE.name

-- ==========================================================================
-- LOG & THÔNG BÁO
-- ==========================================================================
Utils.verbose = false
function Utils.logMsg(msg) if Utils.verbose then BE.log("[AceBot] " .. tostring(msg)) end end
function Utils.notify(msg) BE.toast(tostring(msg)); Utils.logMsg(msg) end

-- ==========================================================================
-- THỜI GIAN
-- ==========================================================================
function Utils.sleepMs(ms) BE.sleep(ms) end

-- ==========================================================================
-- SCALE TOẠ ĐỘ THEO ĐỘ PHÂN GIẢI
-- ==========================================================================
Utils.scaleX = 1.0
Utils.scaleY = 1.0

function Utils.setScale(baseW, baseH)
  local w, h = baseW, baseH
  local rw, rh = BE.screenSize()
  if rw and rh and rw > 0 and rh > 0 then
    w = math.min(rw, rh); h = math.max(rw, rh)   -- canh theo portrait
  end
  Utils.scaleX = w / baseW
  Utils.scaleY = h / baseH
  Utils.logMsg(string.format("Backend=%s  Man hinh=%sx%s  Scale=(%.3f,%.3f)",
    BE.name, tostring(rw), tostring(rh), Utils.scaleX, Utils.scaleY))
end

local function sx(x) return math.floor(x * Utils.scaleX + 0.5) end
local function sy(y) return math.floor(y * Utils.scaleY + 0.5) end
Utils.sx = sx
Utils.sy = sy

-- ==========================================================================
-- TAP / SWIPE / GIỮ-NHẢ
-- ==========================================================================
function Utils.tap(x, y, holdMs)
  holdMs = holdMs or 30
  local px, py = sx(x), sy(y)
  BE.down(px, py); Utils.sleepMs(holdMs); BE.up(px, py)
end

function Utils.tapN(x, y, times, intervalMs, holdMs)
  for i = 1, (times or 1) do
    Utils.tap(x, y, holdMs)
    if i < times then Utils.sleepMs(intervalMs or 60) end
  end
end

-- Giữ (chỉ xuống) / nhả — cho cơ chế giữ-rồi-nhả của tension.
function Utils.press(x, y) BE.down(sx(x), sy(y)) end
function Utils.release(x, y) BE.up(sx(x), sy(y)) end

function Utils.swipe(x1, y1, x2, y2, durationMs, steps)
  steps = steps or 12; durationMs = durationMs or 200
  local ax1, ay1 = sx(x1), sy(y1)
  local ax2, ay2 = sx(x2), sy(y2)
  local stepSleep = durationMs / steps
  BE.down(ax1, ay1); Utils.sleepMs(stepSleep)
  for i = 1, steps do
    local t = i / steps
    BE.move(math.floor(ax1 + (ax2 - ax1) * t + 0.5),
            math.floor(ay1 + (ay2 - ay1) * t + 0.5))
    Utils.sleepMs(stepSleep)
  end
  BE.up(ax2, ay2)
end

-- ==========================================================================
-- MÀU
-- ==========================================================================
local function rgb(color)
  local r = math.floor(color / 0x10000) % 0x100
  local g = math.floor(color / 0x100) % 0x100
  local b = color % 0x100
  return r, g, b
end
Utils.rgb = rgb

function Utils.getColorAt(x, y) return BE.getColor1(sx(x), sy(y)) end

-- Đọc màu nhiều điểm (theo hệ CHUẨN, tự scale) trong 1 lời gọi native.
-- points = { {x,y}, ... } -> { color, ... }
function Utils.getColorsScaled(points)
  local scaled = {}
  for i = 1, #points do scaled[i] = { sx(points[i][1]), sy(points[i][2]) } end
  return BE.getColors(scaled)
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

-- anchor = { x, y, color, tolerance }
function Utils.anchorActive(anchor)
  if not anchor then return false end
  return Utils.colorMatch(Utils.getColorAt(anchor.x, anchor.y), anchor.color, anchor.tolerance)
end

function Utils.waitForAnchor(anchor, timeoutMs, pollMs)
  timeoutMs = timeoutMs or 5000; pollMs = pollMs or 30
  local waited = 0
  while waited < timeoutMs do
    if Utils.anchorActive(anchor) then return true end
    Utils.sleepMs(pollMs); waited = waited + pollMs
  end
  return false
end

-- ==========================================================================
-- THANH LỰC (TENSION) — đọc bằng getColors (batch), tự so màu có sai số
--   bar = { x0, x1, y, fillMinR, fillRB, probes }
--     x0 = mép trái (0%), x1 = mép phải/vạch đứt (100%), probes = số điểm dò.
-- ==========================================================================

-- Tạo danh sách điểm dò dọc thanh (theo hệ chuẩn). Gọi 1 lần rồi tái dùng.
function Utils.makeTensionProbes(bar)
  local n = bar.probes or 28
  local pts = {}
  for i = 1, n do
    local t = (n > 1) and ((i - 1) / (n - 1)) or 0
    pts[i] = { math.floor(bar.x0 + (bar.x1 - bar.x0) * t + 0.5), bar.y }
  end
  return pts, n
end

-- Từ mảng màu đã đọc (colors[1..n] = trái->phải) suy ra % tension.
-- Fill tension = cam/đỏ: đỏ trội hơn xanh dương và đủ sáng. Điểm fill xa nhất = mép.
function Utils.tensionFromColors(colors, n, bar)
  local rb = bar.fillRB or 40
  local minR = bar.fillMinR or 140
  local last = -1
  for i = 1, n do
    local c = colors[i]
    if c then
      local r, g, b = rgb(c)
      if r > b + rb and r > minR then last = i end
    end
  end
  if last < 0 then return 0, false end
  local pct = (n > 1) and ((last - 1) / (n - 1) * 100) or 0
  return pct, true
end

-- Đo % tension một phát (dựng điểm + đọc batch + tính). Dùng cho chỗ chỉ cần
-- đo thanh lực (waitForBite, calibrate). Vòng kéo cá dùng cách gộp thêm anchor
-- vào cùng 1 getColors để tiết kiệm hơn (xem fishing.lua).
function Utils.measureTensionPct(bar)
  local pts, n = Utils.makeTensionProbes(bar)
  local cols = Utils.getColorsScaled(pts)
  return Utils.tensionFromColors(cols, n, bar)
end

return Utils
