--[[
  config.lua — Cấu hình bot câu cá Ace Fishing (AutoTouch / XXTouch, iOS)
  Máy chuẩn: iPhone 7 Plus — 1080 x 1920 (portrait). Máy khác sẽ tự scale.

  QUAN TRỌNG: mọi toạ độ (x,y) và màu (0xRRGGBB) dưới đây là GIÁ TRỊ MẪU.
  Hãy chạy `calibrate.lua` tại đúng màn hình game để lấy số thật rồi dán vào đây.

  Hai tuỳ chọn hay đổi nhất (Perfect on/off, số cá) được hỏi qua UI lúc chạy
  (xem ui.lua) — các giá trị ở mục Config.run bên dưới chỉ là MẶC ĐỊNH của UI.
]]

local Config = {}

-- Độ phân giải chuẩn mà toạ độ dưới đây được canh theo.
Config.screen = { width = 1080, height = 1920 }

-- ============================================================
-- 2 TUỲ CHỌN CHÍNH (mặc định cho UI)
-- ============================================================
Config.run = {
  perfectCast = true,   -- true = canh Perfect khi quăng; false = quăng thường
  targetCount = 0,      -- số cá cần câu rồi dừng (0 = câu vô hạn)
}

-- ============================================================
-- TOẠ ĐỘ NÚT / VÙNG BẤM  (cần hiệu chỉnh)
-- ============================================================
Config.coords = {
  startButton   = { x = 540,  y = 1720 }, -- nút START (quăng cần)
  castTapPoint  = { x = 540,  y = 1720 }, -- điểm tap để CHỐT lực khi canh cast
  reelButton    = { x = 540,  y = 1660 }, -- nút reel/orb (giữ để kéo cá)

  -- Vuốt NỘI LỰC (khi thanh nội lực đầy): vuốt lên trên.
  innerPowerSwipe = {
    from = { x = 540, y = 1500 },
    to   = { x = 540, y = 1050 },
    durationMs = 160,
  },

  -- Điểm bấm để đóng popup phần thưởng / xác nhận sau khi câu xong.
  confirmPoint  = { x = 540,  y = 1780 },
}

-- ============================================================
-- THANH LỰC (TENSION) — đọc bằng getColors (batch, 1 lời gọi native)
--   x0 = mép trái (0%), x1 = mép phải = vạch đứt (100%), y = hàng giữa thanh.
--   probes = số điểm dò dọc thanh trong 1 lần getColors. Nhiều điểm = % mịn hơn
--            nhưng vẫn chỉ 1 lời gọi. 28 điểm trên ~580px ≈ độ phân giải ~3.6%.
--   fillMinR / fillRB = ngưỡng màu mép fill (cam/đỏ). Chỉnh bằng calibrate.
-- ============================================================
Config.tensionBar = {
  x0 = 250,  x1 = 830,  y = 250,
  probes   = 28,    -- số điểm đọc trong 1 getColors (đổi resolution, không đổi số lời gọi)
  fillMinR = 150,   -- kênh đỏ phải đạt mức này
  fillRB   = 40,    -- đỏ phải hơn xanh dương ngần này
}

-- ============================================================
-- ĐIỂM NEO NHẬN DIỆN TRẠNG THÁI QUA MÀU (cần hiệu chỉnh)
-- Mỗi anchor: { x, y, color, tolerance }
-- ============================================================
Config.anchors = {
  -- Màn "sẵn sàng câu" — nút START xanh lá hiện rõ.
  ready = { x = 540, y = 1720, color = 0x39C46B, tolerance = 26 },

  -- Ô ĐÍCH perfect (teal) trên vòng cung lực — dùng để biết gauge đang hiện.
  gaugeTarget = { x = 540, y = 1500, color = 0x27D3C4, tolerance = 34 },

  -- Kim VÀNG đang nằm ĐÈ lên ô đích (thời điểm nên chốt perfect).
  castPerfect = { x = 540, y = 1500, color = 0xFFD200, tolerance = 30 },

  -- Thanh nội lực đã đầy → được phép vuốt nội lực.
  innerPowerReady = { x = 300, y = 300, color = 0x00E0FF, tolerance = 34 },

  -- Màn phần thưởng sau khi câu xong (nền sáng).
  rewardScreen = { x = 540, y = 400, color = 0xFFFFFF, tolerance = 24 },
}

-- ============================================================
-- CƠ CHẾ TENSION (giữ–nhả) — trái tim của phần kéo cá
-- ============================================================
Config.tension = {
  armPct     = 78,   -- chạm mức này thì NHẢ (mô phỏng: cao hơn dễ đứt dây)
  rearmDrop  = 8,    -- chỉ GIỮ LẠI khi đã tụt xuống dưới (armPct - số này)
  releaseMs  = 90,   -- nhả bao lâu rồi mới xét giữ lại (cao = tension tụt nhiều)
  minHoldMs  = 70,   -- giữ tối thiểu ngần này rồi mới được phép nhả
  hookedPct  = 6,    -- tension vượt mức này = coi như đã móc được cá
}

-- ============================================================
-- THAM SỐ THỜI GIAN
-- ============================================================
Config.timing = {
  loopSleepMs        = 40,     -- nghỉ giữa mỗi vòng lặp trạng thái
  tapDownMs          = 30,     -- thời gian giữ 1 lần tap
  reelPollMs         = 30,     -- nhịp quét trong lúc kéo cá
  castGaugeTimeoutMs = 6000,   -- chờ tối đa để gauge hiện sau khi bấm START
  perfectMaxMs       = 4000,   -- bỏ canh perfect sau ngần này rồi chốt thường
  afterCastWaitMaxMs = 18000,  -- chờ tối đa để cá cắn câu sau khi quăng
  fightTimeoutMs     = 60000,  -- thời gian tối đa cho 1 trận kéo cá
  betweenFishDelayMs = 1200,   -- nghỉ giữa 2 lần câu
}

-- ============================================================
-- BẬT/TẮT CƠ CHẾ
-- ============================================================
Config.features = {
  useColorDetection = true,  -- true: dùng màu nhận diện; false: chạy theo thời gian
  useInnerPower     = true,  -- có vuốt nội lực khi thanh đầy hay không
  autoConfirmReward = true,  -- tự đóng popup phần thưởng
  verboseLog        = true,  -- log chi tiết ra console
}

return Config
