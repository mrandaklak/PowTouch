--[[
  benchmark.lua — ĐO THẬT tốc độ đọc màu trên máy bạn (không đoán).

  So sánh:
    - getColor(x,y)              : đọc 1 điểm / 1 lời gọi
    - getColors({1 điểm})        : batch nhưng chỉ 1 điểm
    - getColors({28 điểm})       : batch như vòng kéo cá thật
    - getColors({100 điểm})      : batch nhiều điểm

  Dùng đồng hồ TƯỜNG os.time() (giây) đếm số lời gọi trong ~N giây -> ra
  "lời gọi/giây" và "ms/lời gọi". os.clock() bị loại vì nó là thời gian CPU,
  không tính phần chờ GPU khi grab.

  Cách chạy: mở game tới màn hình bất kỳ (có màu để đọc), chạy benchmark.lua,
  xem console/log.
]]

local function line(s)
  if type(log) == "function" then log(s)
  elseif type(nLog) == "function" then nLog(s) end
  if type(print) == "function" then print(s) end
end

-- Kích thước màn hình để lấy toạ độ hợp lệ.
local W, H = 750, 1334
if type(getScreenResolution) == "function" then
  local rw, rh = getScreenResolution()
  if rw and rh then W, H = rw, rh end
elseif type(screen) == "table" and type(screen.size) == "function" then
  local rw, rh = screen.size()
  if rw and rh then W, H = rw, rh end
end
local cx, cy = math.floor(W / 2), math.floor(H / 2)

local hasGetColor  = (type(getColor) == "function")
local hasGetColors = (type(getColors) == "function")

-- Tạo danh sách n điểm rải quanh giữa màn hình (đều nằm trong màn).
local function makePoints(n)
  local pts = {}
  local x0 = math.floor(W * 0.2)
  local x1 = math.floor(W * 0.8)
  for i = 1, n do
    local t = (n > 1) and ((i - 1) / (n - 1)) or 0
    pts[i] = { math.floor(x0 + (x1 - x0) * t), cy }
  end
  return pts
end

-- Đếm số lần gọi fn() thực hiện được trong ~seconds giây (đồng hồ tường).
local function callsPerSec(fn, seconds)
  seconds = seconds or 3
  -- Canh vào ranh giới giây để bớt sai số của độ phân giải 1s.
  local t0 = os.time()
  while os.time() == t0 do end
  local start = os.time()
  local n = 0
  while (os.time() - start) < seconds do
    fn(); n = n + 1
  end
  local dt = os.time() - start
  if dt <= 0 then dt = seconds end
  return n / dt, n, dt
end

local function report(name, cps)
  local msPer = (cps > 0) and (1000.0 / cps) or -1
  line(string.format("%-26s  %10.0f lời gọi/giây   %8.3f ms/lời gọi", name, cps, msPer))
end

line("================ BENCHMARK ĐỌC MÀU ================")
line(string.format("Màn hình: %dx%d   điểm giữa: (%d,%d)", W, H, cx, cy))
line(string.format("getColor=%s  getColors=%s", tostring(hasGetColor), tostring(hasGetColors)))
line("Đang đo (mỗi mục ~3 giây)...")

if hasGetColor then
  local cps = callsPerSec(function() getColor(cx, cy) end, 3)
  report("getColor (1 điểm)", cps)
end

if hasGetColors then
  local p1  = makePoints(1)
  local p28 = makePoints(28)
  local p100 = makePoints(100)

  local c1 = callsPerSec(function() getColors(p1) end, 3)
  report("getColors (1 điểm)", c1)

  local c28 = callsPerSec(function() getColors(p28) end, 3)
  report("getColors (28 điểm)", c28)
  line(string.format("   -> 28 điểm: %.3f ms/điểm", (c28 > 0) and (1000.0 / c28 / 28) or -1))

  local c100 = callsPerSec(function() getColors(p100) end, 3)
  report("getColors (100 điểm)", c100)
  line(string.format("   -> 100 điểm: %.3f ms/điểm", (c100 > 0) and (1000.0 / c100 / 100) or -1))
end

line("================ Ý NGHĨA ================")
line("- 1 vòng kéo cá dùng getColors(~30 điểm) 1 lần -> nhìn dòng 'getColors (28 điểm)'.")
line("- So 'ms/lời gọi' của getColors(28) với 28 × 'ms/lời gọi' của getColor để thấy")
line("  batch lợi bao nhiêu. Nếu getColors(28) ≈ getColors(1) thì grab mới là phần đắt.")
