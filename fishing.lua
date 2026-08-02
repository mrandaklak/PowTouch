--[[
  fishing.lua — Bot câu cá Ace Fishing cho AutoTouch / XXTouch (iOS jailbreak).

  Nguyên lý (học từ bản JS gốc core/fishing/default.js), rút gọn cho iOS:
    1. QUĂNG   : bấm START -> hiện vòng cung lực -> canh Perfect (nếu bật) rồi chốt.
    2. CHỜ     : chờ thanh lực (tension) xuất hiện = cá đã cắn.
    3. KÉO     : GIỮ nút reel cho tension leo tới vạch (armPct) thì NHẢ; tụt đủ thì
                 giữ lại — dao động sát vạch đứt mà không đứt. Nội lực đầy -> vuốt lên.
    4. KẾT THÚC: đóng popup phần thưởng, đếm cá, lặp lại tới khi đủ số cá.

  Chạy: mở AutoTouch/XXTouch, chọn fishing.lua -> Play. Lần đầu chỉnh toạ độ & màu
  bằng calibrate.lua. Khi chạy sẽ hiện bảng hỏi: Canh Perfect + Số cá cần câu.
]]

-- Nạp module — thêm nhiều thư mục ứng viên vào package.path để require chạy được
-- dù đặt ở gốc Scripts hay clone repo vào subfolder.
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
local UI     = require("lib.ui")

Utils.verbose = Config.features.verboseLog
Utils.setScale(Config.screen.width, Config.screen.height)

-- ---- Hỏi cấu hình (2 tuỳ chọn) rồi áp vào Config ---------------------------
local choice = UI.showConfig(Config.run)
if not choice.ok then
  Utils.notify("Đã huỷ — không chạy.")
  return
end
Config.run.perfectCast = choice.perfectCast
Config.run.targetCount = choice.targetCount

local C  = Config.coords
local A  = Config.anchors
local TB = Config.tensionBar
local TN = Config.tension
local T  = Config.timing
local F  = Config.features

-- Máy trạng thái
local STATE = { READY = "READY", CAST = "CAST", WAIT = "WAIT", FIGHT = "FIGHT", FINISH = "FINISH" }

local running = true
local catches = 0

-- ==========================================================================
-- BƯỚC 1 + 2: QUĂNG CẦN + CANH PERFECT
-- ==========================================================================
local function doCast()
  Utils.notify("Quăng cần...")
  -- Bấm START để mở vòng cung lực.
  Utils.tap(C.startButton.x, C.startButton.y, T.tapDownMs)

  if not F.useColorDetection then
    -- Không nhận diện màu: chờ nửa cửa sổ rồi chốt.
    Utils.sleepMs(T.castGaugeTimeoutMs / 2)
    Utils.tap(C.castTapPoint.x, C.castTapPoint.y, T.tapDownMs)
    return STATE.WAIT
  end

  -- Chờ vòng cung lực hiện (ô đích teal xuất hiện).
  local gaugeUp = Utils.waitForAnchor(A.gaugeTarget, T.castGaugeTimeoutMs, 20)
  if not gaugeUp then
    -- Không thấy gauge: bấm lại START rồi thoát để vòng ngoài thử lại.
    Utils.notify("Không thấy vòng cung lực, thử lại.")
    return STATE.READY
  end

  if Config.run.perfectCast then
    -- CANH PERFECT: chờ kim vàng đè lên ô đích rồi chốt NGAY.
    local hit = Utils.waitForAnchor(A.castPerfect, T.perfectMaxMs, 8)
    Utils.tap(C.castTapPoint.x, C.castTapPoint.y, T.tapDownMs)
    Utils.notify(hit and "Chốt lực PERFECT!" or "Hết giờ canh — chốt thường.")
  else
    -- Quăng thường: chốt luôn.
    Utils.tap(C.castTapPoint.x, C.castTapPoint.y, T.tapDownMs)
    Utils.notify("Quăng thường.")
  end

  return STATE.WAIT
end

-- ==========================================================================
-- BƯỚC 3: CHỜ CÁ CẮN CÂU
-- ==========================================================================
local function waitForBite()
  Utils.notify("Chờ cá cắn câu...")
  if not F.useColorDetection then
    Utils.sleepMs(T.afterCastWaitMaxMs / 4)
    return STATE.FIGHT
  end

  local waited = 0
  while waited < T.afterCastWaitMaxMs do
    local pct, ok = Utils.measureTensionPct(TB)
    if ok and pct > TN.hookedPct then
      Utils.notify("Cá đã cắn câu!")
      return STATE.FIGHT
    end
    Utils.sleepMs(30)
    waited = waited + 30
  end
  Utils.notify("Hết giờ chờ — quăng lại.")
  return STATE.READY
end

-- ==========================================================================
-- BƯỚC 4-5-6: KÉO CÁ — CƠ CHẾ GIỮ–NHẢ TENSION (trọng tâm)
-- ==========================================================================
local function fightFish()
  Utils.notify("Bắt đầu kéo cá!")
  -- KHÔNG dùng đồng hồ thật: os.clock() trên AutoTouch là thời gian CPU, gần như
  -- đứng yên trong lúc usleep. Ta tự CỘNG DỒN thời gian đã ngủ để đo (đủ chính xác
  -- cho các mốc minHold/release cỡ vài chục ms).
  local elapsed   = 0          -- tổng thời gian đã trôi trong trận (ms, xấp xỉ)
  local holding   = false      -- đang giữ nút reel?
  local releaseAt = 0          -- được phép giữ lại khi elapsed >= mốc này (pha nhả)
  local holdSince = 0          -- elapsed lúc bắt đầu giữ hiện tại
  local hooked    = false
  local lastSeen  = 0          -- elapsed lần cuối còn đo được tension (còn cá)

  -- Dựng danh sách điểm dò MỘT LẦN: các điểm thanh lực + 2 anchor (reward, nội lực).
  -- Mỗi vòng chỉ gọi getColors 1 LẦN cho cả danh sách (cơ chế AutoTouch).
  local probes, N = Utils.makeTensionProbes(TB)
  local idxReward = N + 1; probes[idxReward] = { A.rewardScreen.x, A.rewardScreen.y }
  local idxIP     = N + 2; probes[idxIP]     = { A.innerPowerReady.x, A.innerPowerReady.y }

  local function ensureRelease()
    if holding then
      Utils.release(C.reelButton.x, C.reelButton.y)
      holding = false
    end
  end
  local function ensureHold()
    if not holding then
      Utils.press(C.reelButton.x, C.reelButton.y)
      holding = true
      holdSince = elapsed
    end
  end

  while elapsed < T.fightTimeoutMs do
    -- 1 lời gọi native đọc HẾT: thanh lực + reward + nội lực.
    local cols = Utils.getColorsScaled(probes)
    local pct, ok = Utils.tensionFromColors(cols, N, TB)
    local rewardUp = F.useColorDetection
      and Utils.colorMatch(cols[idxReward], A.rewardScreen.color, A.rewardScreen.tolerance)
    local ipReady = F.useInnerPower
      and Utils.colorMatch(cols[idxIP], A.innerPowerReady.color, A.innerPowerReady.tolerance)

    if ok and pct > TN.hookedPct then hooked = true; lastSeen = elapsed end

    -- (a) Kết thúc: hiện màn thưởng, hoặc mất tension đủ lâu sau khi đã móc.
    if rewardUp then
      ensureRelease(); Utils.notify("Đã kéo cá xong."); return STATE.FINISH
    end
    if hooked and (elapsed - lastSeen) > 1500 then
      ensureRelease(); Utils.notify("Mất tension — coi như xong."); return STATE.FINISH
    end

    -- (b) NỘI LỰC đầy -> nhả tay, vuốt lên dùng kỹ năng, rồi giữ lại.
    if ipReady and hooked then
      ensureRelease()
      local ip = C.innerPowerSwipe
      Utils.swipe(ip.from.x, ip.from.y, ip.to.x, ip.to.y, ip.durationMs)
      Utils.sleepMs(60); elapsed = elapsed + 60 + ip.durationMs
      ensureHold()
      releaseAt = 0
    end

    -- (c) LÕI: giữ cho tension leo tới vạch armPct rồi nhả; tụt đủ thì giữ lại.
    if not hooked then
      -- Chưa móc chắc: cứ giữ để móc/kéo.
      ensureHold()
    elseif holding then
      -- Đang giữ: chạm vạch + đã giữ đủ tối thiểu -> NHẢ.
      if ok and pct >= TN.armPct and (elapsed - holdSince) >= TN.minHoldMs then
        ensureRelease()
        releaseAt = elapsed + TN.releaseMs
      end
    else
      -- Đang nhả: hết thời gian nhả VÀ tension đã tụt dưới (vạch - rearmDrop) -> GIỮ LẠI.
      if elapsed >= releaseAt and (not ok or pct <= TN.armPct - TN.rearmDrop) then
        ensureHold()
      end
    end

    Utils.sleepMs(T.reelPollMs)
    elapsed = elapsed + T.reelPollMs
  end

  ensureRelease()
  Utils.notify("Kéo quá lâu — chuyển sang xử lý kết thúc.")
  return STATE.FINISH
end

-- ==========================================================================
-- BƯỚC 7: XỬ LÝ KHI CÂU XONG
-- ==========================================================================
local function finish()
  catches = catches + 1
  Utils.notify(string.format("Câu xong! Tổng: %d con", catches))

  if F.autoConfirmReward then
    -- Bấm vài lần để bỏ qua chuỗi popup phần thưởng.
    for _ = 1, 5 do
      Utils.tap(C.confirmPoint.x, C.confirmPoint.y, T.tapDownMs)
      Utils.sleepMs(400)
      if F.useColorDetection and Utils.anchorActive(A.ready) then break end
    end
  end

  if Config.run.targetCount > 0 and catches >= Config.run.targetCount then
    Utils.notify(string.format("Đã đủ %d con — dừng.", Config.run.targetCount))
    running = false
  end

  Utils.sleepMs(T.betweenFishDelayMs)
  return STATE.READY
end

-- ==========================================================================
-- VÒNG LẶP CHÍNH
-- ==========================================================================
local function main()
  Utils.notify(string.format("=== Ace Fishing bot === Perfect=%s  Mục tiêu=%s",
    tostring(Config.run.perfectCast),
    Config.run.targetCount == 0 and "∞" or tostring(Config.run.targetCount)))

  local state = STATE.READY
  while running do
    if state == STATE.READY then
      if F.useColorDetection and not Utils.anchorActive(A.ready) then
        Utils.sleepMs(T.loopSleepMs)   -- chưa về màn sẵn sàng, chờ.
      else
        state = STATE.CAST
      end
    elseif state == STATE.CAST   then state = doCast()
    elseif state == STATE.WAIT   then state = waitForBite()
    elseif state == STATE.FIGHT  then state = fightFish()
    elseif state == STATE.FINISH then state = finish()
    else
      Utils.notify("Trạng thái lạ: " .. tostring(state)); state = STATE.READY
    end
    Utils.sleepMs(T.loopSleepMs)
  end

  Utils.notify("=== Dừng bot. Tổng cá: " .. catches .. " ===")
end

main()
