--[[
  calibrate.lua — Công cụ hiệu chỉnh toạ độ & màu cho Ace Fishing bot

  Cách dùng:
    1. Mở game Ace Fishing tới đúng màn hình cần lấy dữ liệu.
    2. Chạy script này trong AutoTouch.
    3. Script sẽ đọc màu tại tất cả các điểm neo (anchor) và toạ độ nút
       trong config.lua rồi in ra console để bạn đối chiếu / cập nhật.

  Mẹo lấy toạ độ chính xác: dùng chức năng "Record" của AutoTouch để chạm
  vào đúng nút, xem toạ độ trong file ghi lại, rồi điền vào config.lua.
]]

local dir = (type(rootDir) == "function") and rootDir() or "."
package.path = dir .. "/?.lua;" .. dir .. "/lib/?.lua;" .. package.path

local Config = require("config")
local Utils  = require("lib.utils")

Utils.verbose = true
Utils.setScale(Config.screen.width, Config.screen.height)

local function hex(c)
  if not c then return "nil" end
  return string.format("0x%06X", c)
end

local function line(s)
  if type(log) == "function" then log(s) end
  if type(print) == "function" then print(s) end
end

line("========= CALIBRATE: ĐỌC MÀU CÁC ANCHOR =========")
line(string.format("Scale hiện tại: (%.3f, %.3f)", Utils.scaleX, Utils.scaleY))

for name, a in pairs(Config.anchors) do
  local actual = Utils.getColorAt(a.x, a.y)
  local match  = Utils.colorMatch(actual, a.color, a.tolerance)
  line(string.format(
    "anchor %-16s (%4d,%4d)  màu thực=%s  kỳ vọng=%s  khớp=%s",
    name, a.x, a.y, hex(actual), hex(a.color), tostring(match)))
end

line("========= TOẠ ĐỘ NÚT ĐANG CẤU HÌNH =========")
for name, p in pairs(Config.coords) do
  if p.x and p.y then
    local c = Utils.getColorAt(p.x, p.y)
    line(string.format("coord  %-16s (%4d,%4d)  màu tại đó=%s",
      name, p.x, p.y, hex(c)))
  end
end

line("========= GỢI Ý =========")
line("- Cập nhật 'color' trong config.anchors bằng cột 'màu thực' ở trên.")
line("- Chỉnh 'tolerance' nếu màu dao động (thường 20-40 là ổn).")
line("- Dùng AutoTouch Record để lấy toạ độ nút chính xác.")
