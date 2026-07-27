--[[
  fishing.lua — Script câu cá Ace Fishing cho AutoTouch (iOS, iPhone 7 Plus)

  Luồng câu cá (theo yêu cầu):
    1. Nhấn START để quăng cần.
    2. Canh thanh lực và chốt tại vạch PERFECT (quăng perfect).
    3. Chờ cá cắn câu.
    4. Khi kéo cá: NHẤP TENSION liên tục để giữ lực căng dây.
    5. Khi thanh NỘI LỰC đầy: VUỐT để dùng kỹ năng nội lực.
    6. GIẬT CẦN để thu cá về.
    7. Xử lý khi câu xong: đóng popup phần thưởng rồi quay lại bước 1.

  Cách chạy: mở AutoTouch, đặt cả thư mục vào scripts, chạy file này.
  Trước khi chạy lần đầu: dùng calibrate.lua để lấy đúng toạ độ & màu.

  Lưu ý: viết cho máy ĐÃ JAILBREAK dùng AutoTouch.
]]

-- Nạp config & thư viện tiện ích ------------------------------------------
local dir = (type(rootDir) == "function") and rootDir() or "."
package.path = dir .. "/?.lua;" .. dir .. "/lib/?.lua;" .. package.path

local Config = require("config")
local Utils  = require("lib.utils")

Utils.verbose = Config.features.verboseLog
Utils.setScale(Config.screen.width, Config.screen.height)

local C  = Config.coords
local A  = Config.anchors
local T  = Config.timing
local F  = Config.features

-- Các trạng thái của máy trạng thái ---------------------------------------
local STATE = {
  READY   = "READY",   -- sẵn sàng, sắp quăng
  CAST    = "CAST",    -- đang canh lực quăng
  WAIT    = "WAIT",    -- chờ cá cắn câu
  FIGHT   = "FIGHT",   -- đang kéo cá
  FINISH  = "FINISH",  -- câu xong, xử lý phần thưởng
}

local running   = true
local catches   = 0

-- ==========================================================================
-- BƯỚC 1 + 2: QUĂNG CẦN + CANH PERFECT
-- ==========================================================================
local function doCast()
  Utils.notify("Quăng cần...")
  -- Nhấn START để bắt đầu quăng (thanh lực bắt đầu chạy)
  Utils.tap(C.startButton.x, C.startButton.y, T.tapDownMs)

  if F.useColorDetection then
    -- Chờ thanh lực chạy tới vùng PERFECT rồi chốt ngay
    local perfect = Utils.waitForAnchor(A.castPerfect, T.castGaugeTimeoutMs, 10)
    if perfect then
      Utils.tap(C.castTapPoint.x, C.castTapPoint.y, T.tapDownMs)
      Utils.notify("Chốt lực PERFECT!")
    else
      -- Không bắt được vạch perfect → chốt luôn để không kẹt
      Utils.tap(C.castTapPoint.x, C.castTapPoint.y, T.tapDownMs)
      Utils.notify("Không thấy vạch perfect, chốt lực mặc định.")
    end
  else
    -- Chế độ theo thời gian: chờ 1 khoảng cố định rồi chốt
    Utils.sleepMs(T.castGaugeTimeoutMs / 2)
    Utils.tap(C.castTapPoint.x, C.castTapPoint.y, T.tapDownMs)
  end

  return STATE.WAIT
end

-- ==========================================================================
-- BƯỚC 3: CHỜ CÁ CẮN CÂU
-- ==========================================================================
local function waitForBite()
  Utils.notify("Chờ cá cắn câu...")
  if F.useColorDetection then
    local hooked = Utils.waitForAnchor(A.fishHooked, T.afterCastWaitMaxMs, 30)
    if hooked then
      Utils.notify("Cá đã cắn câu!")
      return STATE.FIGHT
    end
    -- Hết thời gian chờ mà không có cá → thử quăng lại
    Utils.notify("Hết thời gian chờ, quăng lại.")
    return STATE.READY
  else
    Utils.sleepMs(T.afterCastWaitMaxMs / 4)
    return STATE.FIGHT
  end
end

-- ==========================================================================
-- BƯỚC 4-5-6: KÉO CÁ (tension + nội lực + giật cần)
-- ==========================================================================
local function fightFish()
  Utils.notify("Bắt đầu kéo cá!")
  local elapsed = 0
  local pollMs  = T.tensionTapIntervalMs

  while elapsed < T.fightTimeoutMs do
    -- (a) Nếu dây quá căng (vùng nguy hiểm) → NGỪNG nhấp để tránh đứt dây
    local danger = F.useColorDetection and Utils.anchorActive(A.tensionDanger)

    if danger then
      -- Nhả tay, chờ lực căng giảm bớt
      Utils.logMsg("Dây quá căng — tạm ngừng nhấp tension.")
      Utils.sleepMs(pollMs)
    else
      -- (b) NHẤP TENSION để duy trì lực căng dây
      Utils.tap(C.tensionButton.x, C.tensionButton.y, T.tapDownMs)
    end

    -- (c) Nếu thanh NỘI LỰC đầy → VUỐT dùng kỹ năng nội lực
    if F.useInnerPower then
      if (not F.useColorDetection) or Utils.anchorActive(A.innerPowerReady) then
        if F.useColorDetection then
          Utils.notify("Nội lực đầy — vuốt kỹ năng!")
        end
        local ip = C.innerPowerSwipe
        Utils.swipe(ip.from.x, ip.from.y, ip.to.x, ip.to.y, ip.durationMs)
        -- (d) GIẬT CẦN ngay sau khi dùng nội lực để thu cá mạnh
        Utils.tap(C.reelButton.x, C.reelButton.y, T.tapDownMs)
      end
    end

    -- (e) Kiểm tra đã câu xong chưa (hiện màn phần thưởng / hết nút tension)
    if F.useColorDetection then
      local rewardUp   = Utils.anchorActive(A.rewardScreen)
      local stillFight = Utils.anchorActive(A.fishHooked)
      if rewardUp or (not stillFight) then
        Utils.notify("Đã kéo cá xong.")
        return STATE.FINISH
      end
    end

    Utils.sleepMs(pollMs)
    elapsed = elapsed + pollMs
  end

  Utils.notify("Kéo cá quá lâu — chuyển sang xử lý kết thúc.")
  return STATE.FINISH
end

-- ==========================================================================
-- BƯỚC 7: XỬ LÝ KHI CÂU XONG
-- ==========================================================================
local function finish()
  catches = catches + 1
  Utils.notify(string.format("Câu xong! Tổng: %d con", catches))

  if F.autoConfirmReward then
    -- Bấm nhiều lần để bỏ qua các popup phần thưởng nối tiếp nhau
    for _ = 1, 5 do
      Utils.tap(C.confirmPoint.x, C.confirmPoint.y, T.tapDownMs)
      Utils.sleepMs(400)
      -- Nếu đã về màn hình sẵn sàng thì dừng bấm
      if F.useColorDetection and Utils.anchorActive(A.ready) then
        break
      end
    end
  end

  if Config.maxCatches > 0 and catches >= Config.maxCatches then
    Utils.notify("Đã đạt số cá tối đa, dừng script.")
    running = false
  end

  Utils.sleepMs(T.betweenFishDelayMs)
  return STATE.READY
end

-- ==========================================================================
-- VÒNG LẶP CHÍNH (máy trạng thái)
-- ==========================================================================
local function main()
  Utils.notify("=== Ace Fishing bot bắt đầu ===")
  local state = STATE.READY

  while running do
    if state == STATE.READY then
      -- Nếu có nhận diện màu, đợi tới khi đúng màn hình sẵn sàng
      if F.useColorDetection and not Utils.anchorActive(A.ready) then
        Utils.sleepMs(T.loopSleepMs)
      else
        state = STATE.CAST
      end

    elseif state == STATE.CAST then
      state = doCast()

    elseif state == STATE.WAIT then
      state = waitForBite()

    elseif state == STATE.FIGHT then
      state = fightFish()

    elseif state == STATE.FINISH then
      state = finish()

    else
      Utils.notify("Trạng thái lạ: " .. tostring(state))
      state = STATE.READY
    end

    Utils.sleepMs(T.loopSleepMs)
  end

  Utils.notify("=== Dừng bot. Tổng cá: " .. catches .. " ===")
end

main()
