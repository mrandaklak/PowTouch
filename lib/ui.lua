--[[
  lib/ui.lua — Bảng cấu hình hiện ra TRƯỚC khi chạy bot.

  Hỏi đúng 2 tuỳ chọn:
    1. Canh Perfect     (bật/tắt)
    2. Số cá cần câu    (0 = vô hạn)

  Dùng dialog() của AutoTouch. API dialog KHÁC NHAU theo bản: đối số thứ 2
  (orientations) có bản nhận BẢNG {ORIENTATION_TYPE.PORTRAIT}, có bản nhận SỐ,
  có bản không cần. Nên ta gọi PHÒNG THỦ bằng pcall: thử lần lượt, cái nào chạy
  thì dùng; nếu hỏng hết thì rơi về giá trị mặc định để bot vẫn chạy được.

  Trả về: { perfectCast = bool, targetCount = number, ok = bool }
]]

local UI = {}

local function safeLog(msg)
  if type(log) == "function" then log(msg)
  elseif type(nLog) == "function" then nLog(msg) end
end

local function valueByKey(controls, key)
  for _, c in ipairs(controls) do
    if c.key == key then return c.value end
  end
  return nil
end

local function toBool(v)
  if type(v) == "boolean" then return v end
  if type(v) == "number" then return v ~= 0 end
  if type(v) == "string" then
    v = v:lower()
    return v == "1" or v == "true" or v == "on" or v == "yes"
  end
  return false
end

local function toCount(v)
  local n = tonumber(v)
  if not n or n < 0 then n = 0 end
  return math.floor(n)
end

function UI.showConfig(defaults)
  defaults = defaults or {}
  local defPerfect = defaults.perfectCast and 1 or 0
  local defCount   = tostring(defaults.targetCount or 0)

  local function fallback()
    return { perfectCast = toBool(defPerfect), targetCount = toCount(defCount), ok = true }
  end

  -- Không có dialog (hoặc thiếu CONTROLLER_TYPE) -> chạy với mặc định.
  if type(dialog) ~= "function" or type(CONTROLLER_TYPE) ~= "table" then
    safeLog("[ui] Không có dialog/CONTROLLER_TYPE -> dùng mặc định")
    return fallback()
  end

  local controls = {
    { type = CONTROLLER_TYPE.LABEL,  text = "Ace Fishing - Cau hinh" },
    { type = CONTROLLER_TYPE.SWITCH, key = "perfect", title = "Canh Perfect", value = defPerfect },
    { type = CONTROLLER_TYPE.INPUT,  key = "count",   title = "So ca can cau (0 = vo han)", value = defCount },
    { type = CONTROLLER_TYPE.BUTTON, title = "Bat dau", color = 0x1E90FF, flag = 1, collectInputs = true },
    { type = CONTROLLER_TYPE.BUTTON, title = "Huy",     color = 0x8E8E93, flag = 2, collectInputs = false },
  }

  -- Chuẩn bị các kiểu orientations có thể có.
  local oriTable, oriNum
  if type(ORIENTATION_TYPE) == "table" and ORIENTATION_TYPE.PORTRAIT ~= nil then
    oriTable = { ORIENTATION_TYPE.PORTRAIT }
    oriNum   = ORIENTATION_TYPE.PORTRAIT
  else
    oriTable = { 1 }
    oriNum   = 1
  end

  -- Thử lần lượt các cách gọi; cái nào KHÔNG lỗi thì dùng.
  local attempts = {
    function() return dialog(controls, oriTable) end,  -- orientations là BẢNG (AutoTouch 8.x)
    function() return dialog(controls, oriNum)   end,  -- orientations là SỐ
    function() return dialog(controls)           end,  -- không truyền orientations
  }

  local called, result, lastErr = false, nil, nil
  for i = 1, #attempts do
    local okCall, res = pcall(attempts[i])
    if okCall then
      called = true; result = res; break
    else
      lastErr = res
      safeLog("[ui] cách gọi dialog #" .. i .. " lỗi: " .. tostring(res))
    end
  end

  if not called then
    safeLog("[ui] Mọi cách gọi dialog đều lỗi (" .. tostring(lastErr) .. ") -> dùng mặc định")
    return fallback()
  end

  -- result thường là flag nút bấm (1 = Bắt đầu, 2 = Huỷ). Bản trả về khác thì
  -- coi như OK và đọc giá trị đã cập nhật trong controls.
  local ok = true
  if type(result) == "number" then ok = (result == 1) end

  return {
    perfectCast = toBool(valueByKey(controls, "perfect")),
    targetCount = toCount(valueByKey(controls, "count")),
    ok = ok,
  }
end

return UI
