--[[
  lib/ui.lua — Bảng cấu hình hiện ra TRƯỚC khi chạy bot.

  Hỏi đúng 2 tuỳ chọn theo yêu cầu:
    1. Canh Perfect     (bật/tắt)
    2. Số cá cần câu    (0 = vô hạn) — câu đủ số này thì dừng.

  Dùng dialog() của AutoTouch. Nếu môi trường không có dialog (vd XXTouch chạy
  headless), tự bỏ qua và trả về giá trị mặc định trong config.

  Trả về: table { perfectCast = bool, targetCount = number, ok = bool }
    ok = false nghĩa là người dùng bấm Huỷ (không nên chạy).
]]

local UI = {}

-- Đọc lại value của 1 control theo key sau khi dialog đóng.
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

-- Hiện bảng cấu hình. `defaults` = Config.run.
function UI.showConfig(defaults)
  defaults = defaults or {}
  local defPerfect = defaults.perfectCast and 1 or 0
  local defCount   = tostring(defaults.targetCount or 0)

  -- Không có dialog (hoặc thiếu hằng CONTROLLER_TYPE) -> dùng mặc định, chạy luôn.
  if type(dialog) ~= "function" or type(CONTROLLER_TYPE) ~= "table" then
    return {
      perfectCast = toBool(defPerfect),
      targetCount = toCount(defCount),
      ok = true,
    }
  end

  local controls = {
    { type = CONTROLLER_TYPE.LABEL,
      text = "🎣 Ace Fishing — Cấu hình" },

    { type = CONTROLLER_TYPE.SWITCH,
      key = "perfect",
      title = "Canh Perfect",
      value = defPerfect },

    { type = CONTROLLER_TYPE.INPUT,
      key = "count",
      title = "Số cá cần câu (0 = vô hạn)",
      value = defCount },

    { type = CONTROLLER_TYPE.BUTTON,
      title = "Bắt đầu",
      color = 0x1E90FF, width = 0.5, flag = 1, collectInputs = true },

    { type = CONTROLLER_TYPE.BUTTON,
      title = "Huỷ",
      color = 0x8E8E93, width = 0.5, flag = 2, collectInputs = false },
  }

  local orientation = (type(ORIENTATION_TYPE) == "table" and ORIENTATION_TYPE.PORTRAIT) or 0
  local result = dialog(controls, orientation)

  -- `result` là flag nút được bấm (1 = Bắt đầu, 2 = Huỷ). Một số bản trả về
  -- table controls; khi đó coi như OK (giá trị đã nằm trong controls).
  local ok = true
  if type(result) == "number" then
    ok = (result == 1)
  end

  return {
    perfectCast = toBool(valueByKey(controls, "perfect")),
    targetCount = toCount(valueByKey(controls, "count")),
    ok = ok,
  }
end

return UI
