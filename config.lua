--[[
  config.lua — Cấu hình cho script câu cá Ace Fishing (AutoTouch / iOS)
  Thiết bị mục tiêu: iPhone 7 Plus — độ phân giải 1080 x 1920 (portrait)

  Bạn chỉ cần quan tâm mục "CONFIG CƠ BẢN" ngay dưới đây.
  Phần "NÂNG CAO / HIỆU CHỈNH" bên dưới là toạ độ & màu — chỉ chỉnh khi
  hiệu chỉnh cho đúng máy (dùng calibrate.lua).
]]

local Config = {}

-- ============================================================
-- ⭐ CONFIG CƠ BẢN — thường chỉ cần chỉnh 3 mục này
-- ============================================================
Config.basic = {
  -- 1) Canh vạch PERFECT khi quăng cần
  --    true  = canh perfect (quăng chuẩn/xa hơn)
  --    false = quăng thường, bấm chốt luôn không canh
  tapPerfect = true,

  -- 2) Số cá tối đa rồi tự dừng  (0 = không giới hạn)
  maxCatches = 0,

  -- 3) Thời gian chạy tối đa, tính bằng GIỜ  (0 = không giới hạn)
  --    ví dụ: 1.5 = 1 tiếng 30 phút
  maxHours = 0,
}

-- ============================================================
-- NÂNG CAO / HIỆU CHỈNH  (chỉ chỉnh khi cần)
-- ============================================================

-- Độ phân giải màn hình chuẩn mà toạ độ dưới đây được canh theo.
-- Nếu máy khác, script sẽ tự scale theo tỉ lệ.
Config.screen = { width = 1080, height = 1920 }

-- ----- TOẠ ĐỘ NÚT / VÙNG BẤM (cần hiệu chỉnh bằng calibrate.lua) -----
Config.coords = {
  -- Nút bắt đầu / quăng cần (ở màn hình chuẩn bị câu)
  startButton   = { x = 540,  y = 1720 },

  -- Điểm bấm để "chốt" lực quăng khi thanh gauge chạy tới vạch perfect.
  castTapPoint  = { x = 540,  y = 1720 },

  -- Nút "tension" (nhấn giữ / nhấp giữ lực căng dây) khi đang kéo cá
  tensionButton = { x = 540,  y = 1600 },

  -- Thao tác "vuốt nội lực" (dùng kỹ năng nội lực khi thanh đầy)
  innerPowerSwipe = {
    from = { x = 540, y = 1400 },
    to   = { x = 540, y = 900  },
    durationMs = 180,
  },

  -- Nút / thao tác "giật cần" (reel-in mạnh)
  reelButton    = { x = 540,  y = 1600 },

  -- Điểm bấm để đóng popup phần thưởng / xác nhận sau khi câu xong.
  confirmPoint  = { x = 540,  y = 1780 },
}

-- ----- ĐIỂM NEO NHẬN DIỆN TRẠNG THÁI QUA MÀU (cần hiệu chỉnh) -----
-- Mỗi anchor gồm toạ độ điểm đọc màu + màu kỳ vọng (0xRRGGBB) + sai số.
Config.anchors = {
  -- Màn hình "sẵn sàng câu" (nút start hiện rõ)
  ready = {
    x = 540, y = 1720, color = 0x39C46B, tolerance = 24,
  },

  -- Thanh lực quăng đang chạy tới VÙNG PERFECT (màu nổi bật)
  castPerfect = {
    x = 540, y = 1500, color = 0xFFD200, tolerance = 30,
  },

  -- Cá đã cắn câu / bắt đầu kéo (xuất hiện nút tension)
  fishHooked = {
    x = 540, y = 1600, color = 0xFF5A3C, tolerance = 30,
  },

  -- Thanh nội lực đã đầy → được phép vuốt nội lực
  innerPowerReady = {
    x = 300, y = 1300, color = 0x00E0FF, tolerance = 30,
  },

  -- Vùng cảnh báo dây quá căng (nên NHẢ tay để tránh đứt dây)
  tensionDanger = {
    x = 850, y = 1300, color = 0xFF0000, tolerance = 40,
  },

  -- Màn hình phần thưởng sau khi câu xong
  rewardScreen = {
    x = 540, y = 400, color = 0xFFFFFF, tolerance = 24,
  },
}

-- ----- THAM SỐ THỜI GIAN -----
Config.timing = {
  loopSleepMs         = 50,    -- nghỉ giữa mỗi vòng lặp trạng thái
  tapDownMs           = 30,    -- thời gian giữ 1 lần tap
  afterCastWaitMaxMs  = 20000, -- chờ tối đa để cá cắn câu sau khi quăng
  fightTimeoutMs      = 60000, -- thời gian tối đa cho 1 trận kéo cá
  tensionTapIntervalMs= 120,   -- khoảng cách giữa 2 lần nhấp/kiểm tra tension
  betweenFishDelayMs  = 1500,  -- nghỉ giữa 2 lần câu
  castGaugeTimeoutMs  = 4000,  -- chờ tối đa để canh vạch perfect
}

-- ----- Cơ chế TENSION -----
Config.tension = {
  -- "hold": NHẤN GIỮ để kéo, NHẢ ra khi dây sắp căng đứt (giống chơi tay).
  -- "tap" : nhấp liên tục (đơn giản hơn nhưng dễ đứt dây).
  mode = "hold",
}

-- ----- Cơ chế nội bộ -----
Config.features = {
  useColorDetection = true,   -- true: dùng màu nhận diện; false: chạy theo thời gian
  autoConfirmReward = true,   -- tự đóng popup phần thưởng
  verboseLog        = true,   -- log chi tiết ra console
}

return Config
