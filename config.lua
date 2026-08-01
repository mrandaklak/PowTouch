--[[
  config.lua — Cấu hình cho script câu cá Ace Fishing (AutoTouch / iOS)
  Thiết bị mục tiêu: iPhone 7 Plus — độ phân giải 1080 x 1920 (portrait)

  QUAN TRỌNG:
  - Tất cả toạ độ (x, y) và màu (color) dưới đây là GIÁ TRỊ MẪU.
  - Bạn PHẢI hiệu chỉnh lại bằng script `calibrate.lua` cho đúng máy của mình.
  - Màu lấy theo định dạng số nguyên 0xRRGGBB mà AutoTouch trả về từ getColor().
]]

local Config = {}

-- Độ phân giải màn hình chuẩn mà toạ độ dưới đây được canh theo.
-- Nếu máy khác, script main sẽ tự scale theo tỉ lệ.
Config.screen = { width = 1080, height = 1920 }

-- ============================================================
-- TOẠ ĐỘ NÚT / VÙNG BẤM  (cần hiệu chỉnh)
-- ============================================================
Config.coords = {
  -- Nút bắt đầu / quăng cần (ở màn hình chuẩn bị câu)
  startButton   = { x = 540,  y = 1720 },

  -- Điểm bấm để "chốt" lực quăng khi thanh gauge chạy tới vạch perfect.
  -- Với Ace Fishing thường bấm lại đúng nút quăng để chốt lực.
  castTapPoint  = { x = 540,  y = 1720 },

  -- Nút "tension" (nhấp giữ lực căng dây) khi đang kéo cá
  tensionButton = { x = 540,  y = 1600 },

  -- Điểm bắt đầu & kết thúc thao tác "vuốt nội lực" (dùng kỹ năng nội lực)
  innerPowerSwipe = {
    from = { x = 540, y = 1400 },
    to   = { x = 540, y = 900  },
    durationMs = 180,
  },

  -- Nút / thao tác "giật cần" (reel-in mạnh)
  reelButton    = { x = 540,  y = 1600 },

  -- Điểm bấm để đóng popup phần thưởng / xác nhận sau khi câu xong.
  -- Đặt ở vùng trung tính, bấm nhiều lần để bỏ qua các popup nối tiếp.
  confirmPoint  = { x = 540,  y = 1780 },
}

-- ============================================================
-- ĐIỂM NEO ĐỂ NHẬN DIỆN TRẠNG THÁI QUA MÀU (cần hiệu chỉnh)
-- Mỗi anchor gồm toạ độ điểm cần đọc màu + màu kỳ vọng + sai số cho phép.
-- ============================================================
Config.anchors = {
  -- Màn hình đang ở trạng thái "sẵn sàng câu" (nút start hiện rõ)
  ready = {
    x = 540, y = 1720, color = 0x39C46B, tolerance = 24,
  },

  -- Thanh lực quăng đang chạy tới VÙNG PERFECT (thường có màu nổi bật)
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

  -- Vùng cảnh báo dây quá căng (nên NGỪNG nhấp tension để tránh đứt dây)
  tensionDanger = {
    x = 850, y = 1300, color = 0xFF0000, tolerance = 40,
  },

  -- Màn hình phần thưởng sau khi câu xong
  rewardScreen = {
    x = 540, y = 400, color = 0xFFFFFF, tolerance = 24,
  },
}

-- ============================================================
-- THAM SỐ THỜI GIAN / HÀNH VI
-- ============================================================
Config.timing = {
  loopSleepMs         = 50,    -- nghỉ giữa mỗi vòng lặp trạng thái
  tapDownMs           = 30,    -- thời gian giữ 1 lần tap
  afterCastWaitMaxMs  = 20000, -- chờ tối đa để cá cắn câu sau khi quăng
  fightTimeoutMs      = 60000, -- thời gian tối đa cho 1 trận kéo cá
  tensionTapIntervalMs= 120,   -- khoảng cách giữa 2 lần nhấp tension
  betweenFishDelayMs  = 1500,  -- nghỉ giữa 2 lần câu
  castGaugeTimeoutMs  = 4000,  -- chờ tối đa để canh vạch perfect
}

-- Cơ chế TENSION (giữ lực căng dây khi kéo cá)
Config.tension = {
  -- "hold" : NHẤN GIỮ để kéo (tension tăng), NHẢ ra khi dây sắp căng đứt,
  --          rồi giữ lại khi an toàn — giống cách chơi tay. (khuyên dùng)
  -- "tap"  : nhấp liên tục (cơ chế cũ, đơn giản hơn nhưng dễ đứt dây).
  mode = "hold",
}

-- Bật/tắt các cơ chế
Config.features = {
  useColorDetection = true,   -- true: dùng màu để nhận diện; false: chạy theo thời gian
  useInnerPower     = true,   -- có dùng kỹ năng nội lực hay không
  autoConfirmReward = true,   -- tự đóng popup phần thưởng
  verboseLog        = true,   -- log chi tiết ra console AutoTouch
}

-- Số lần câu tối đa trước khi dừng (0 = chạy vô hạn)
Config.maxCatches = 0

return Config
