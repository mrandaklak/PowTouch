--[[
  calibrate.lua — Đọc màu & toạ độ hiện tại để hiệu chỉnh config.lua.

  Cách dùng:
    1. Mở game Ace Fishing tới đúng màn hình cần lấy dữ liệu.
    2. Chạy script này. Nó in ra: màu thực tại từng anchor, màu tại các nút, và
       % đo được của thanh lực (tension) theo cấu hình hiện tại.
    3. Dán 'màu thực' vào Config.anchors.*.color; chỉnh tolerance (20–40).
    4. Lấy toạ độ nút chính xác bằng công cụ chọn điểm (XXTouch) / Record (AutoTouch).
]]

local function addPaths(d)
  if d and #d > 0 then
    package.path = d .. "/?.lua;" .. d .. "/lib/?.lua;" .. package.path
  end
end
local info = (type(debug) == "table" and debug.getinfo) and debug.getinfo(1, "S") or nil
if info and info.source then
  addPaths(info.source:gsub("^@", ""):match("^(.*)[/\\][^/\\]+$"))
end
if type(rootDir) == "function" then
  addPaths(rootDir())
  addPaths(rootDir() .. "/PowTouch")
end
addPaths(".")

local Config = require("config")
local Utils  = require("lib.utils")

Utils.verbose = true
Utils.setScale(Config.screen.width, Config.screen.height)

local function hex(c) return c and string.format("0x%06X", c) or "nil" end
local function line(s)
  if type(log) == "function" then log(s)
  elseif type(nLog) == "function" then nLog(s) end
  if type(print) == "function" then print(s) end
end

line("========= CALIBRATE — backend: " .. Utils.backendName .. " =========")
line(string.format("Scale: (%.3f, %.3f)", Utils.scaleX, Utils.scaleY))

line("----- ANCHORS (màu nhận diện trạng thái) -----")
for name, a in pairs(Config.anchors) do
  local actual = Utils.getColorAt(a.x, a.y)
  local match  = Utils.colorMatch(actual, a.color, a.tolerance)
  line(string.format("%-16s (%4d,%4d)  thuc=%s  ky_vong=%s  khop=%s",
    name, a.x, a.y, hex(actual), hex(a.color), tostring(match)))
end

line("----- TOẠ ĐỘ NÚT -----")
for name, p in pairs(Config.coords) do
  if p.x and p.y then
    line(string.format("%-16s (%4d,%4d)  mau=%s", name, p.x, p.y, hex(Utils.getColorAt(p.x, p.y))))
  end
end

line("----- THANH LỰC (tension) -----")
local pct, ok = Utils.measureTensionPct(Config.tensionBar)
line(string.format("Do duoc: %.1f%%  (co_fill=%s)  — thanh: x0=%d x1=%d y=%d",
  pct, tostring(ok), Config.tensionBar.x0, Config.tensionBar.x1, Config.tensionBar.y))

line("========= GỢI Ý =========")
line("- Dán cột 'thuc' vào Config.anchors.*.color; chỉnh tolerance 20-40.")
line("- Với thanh lực: chỉnh x0 (0%), x1 (vạch đứt 100%), y; nếu do_duoc sai thì")
line("  chỉnh fillMinR / fillRB trong Config.tensionBar.")
