--[[
  fishing.lua — Bot câu cá Ace Fishing cho AutoTouch (iOS). FILE ĐỘC LẬP.
  Không cần config.lua / lib/ — copy đúng file này là chạy.

  Nguyên lý: QUĂNG (canh Perfect) -> CHỜ cắn -> KÉO (giữ–nhả tension, đọc thanh
  lực bằng getColors 1 lời gọi/vòng) -> đóng popup -> lặp tới khi đủ số cá.

  ===================  CHỈNH NHANH 2 TUỲ CHỌN CHÍNH  ===================
  Nếu bảng cấu hình không mở được thì sửa 2 dòng trong RUN dưới đây.
  Toạ độ & màu bên dưới là MẪU (iPhone 7 Plus 1080x1920) — dùng bộ chọn điểm/màu
  của AutoTouch để lấy số thật rồi thay vào.
  =====================================================================
]]

local RUN = {
  perfectCast = true,   -- true = canh Perfect khi quăng; false = quăng thường
  targetCount = 0,      -- số cá cần câu rồi dừng (0 = câu vô hạn)
}

local BASE_W, BASE_H = 1080, 1920   -- độ phân giải mà toạ độ dưới đây canh theo

-- Toạ độ nút / vùng bấm — ĐO TỪ VIDEO MÀN HÌNH THẬT (1080x1920, iPhone Plus).
local COORDS = {
  startButton   = { x = 540,  y = 1575 }, -- nút START (quăng cần)
  castTapPoint  = { x = 540,  y = 1575 }, -- cùng nút START, hiện "TAP" để chốt lực
  reelButton    = { x = 540,  y = 1590 }, -- nút reel/orb (giữ để kéo cá)
  innerPowerSwipe = { from = { x = 540, y = 1500 }, to = { x = 540, y = 1050 }, durationMs = 160 },
  confirmPoint  = { x = 55,   y = 120  }, -- mũi tên "<" quay lại (dự phòng)
  -- 4 nút đáy màn KẾT QUẢ. Ưu tiên xử lý cá: Hội -> Thêm(Add) -> Bán.
  btnHoi  = { x = 420, y = 1755 },  -- Hội (góp cá cho hội)
  btnThem = { x = 910, y = 1755 },  -- Thêm / Add (vào bộ sưu tập)
  btnBan  = { x = 660, y = 1755 },  -- Bán
}

-- Thanh lực (tension): NGANG ở trên cùng. x0=0%, x1=100%(vạch "HIGH"/đứt), y=hàng bar.
-- Fill đỏ/cam đo thật ~0xFE6559..0xF99F56 (R 249-254) -> fillMinR=150, fillRB=40 khớp.
-- x1=1000: dừng TRƯỚC chữ "HIGH" đỏ (x~1020-1040) kẻo bị tính nhầm là fill -> luôn 100%.
local TBAR = { x0 = 315, x1 = 1000, y = 115, probes = 30, fillMinR = 150, fillRB = 40 }

-- Anchor màu: { x, y, color(0xRRGGBB), tol } — màu đo thật từ video.
local ANCH = {
  ready       = { x = 515, y = 1558, color = 0x0098B9, tol = 40 }, -- mặt xanh nút START (đo THẬT trên máy)
  gaugeTarget = { x = 535, y = 1180, color = 0x5E9999, tol = 42 }, -- vùng teal vòng cung (gauge hiện)
  castPerfect = { x = 550, y = 1180, color = 0xF2D515, tol = 60 }, -- kim VÀNG về tâm = perfect
  rewardScreen= { x = 540, y = 1130, color = 0x000000, tol = 12 }, -- (phụ) — chủ yếu dựa vào "mất tension"
  innerPowerReady = { x = 915, y = 1620, color = 0x00E0FF, tol = 34 }, -- nút "Nhiệt Huyết" (đang TẮT tính năng)
  resultBtn   = { x = 660, y = 1755, color = 0x016A9C, tol = 40 }, -- dãy nút xanh đáy = ĐANG ở màn kết quả
}

-- Cơ chế GHIM SÁT VẠCH: giữ tension trong dải [armPct-rearmDrop, armPct].
--   armPct=vạch nhả, rearmDrop=dải hẹp bên dưới để giữ lại. Dải nhỏ = ghim sát hơn.
--   (releaseMs/minHoldMs không còn dùng ở chế độ ghim liên tục — giữ lại tham khảo.)
local TEN = { armPct = 95, rearmDrop = 3, releaseMs = 90, minHoldMs = 70, hookedPct = 6 }

-- Thời gian (ms)
local TIME = {
  loopSleep = 40, tapDown = 30, reelPoll = 10,
  castGaugeTimeout = 2500, perfectMax = 3000,
  afterCastWaitMax = 18000, fightTimeout = 60000, betweenFish = 1200,
}

-- useInnerPower=false: nội lực trong game này là TAP nút "Nhiệt Huyết", chưa có màu
-- "sẵn sàng" tin cậy nên tạm tắt để tránh bấm nhầm. Bật lại sau khi canh được.
local FEAT = { useColorDetection = true, useInnerPower = false, autoConfirmReward = true, verboseLog = true }

-- ==========================================================================
-- BACKEND (AutoTouch chính; XXTouch dự phòng)
-- ==========================================================================
local hasAutoTouch = (type(touchDown) == "function")
local hasXXTouch   = (type(touch) == "table" and type(touch.on) == "function")

local BE = {}
if hasAutoTouch then
  local FID = 2
  BE.down = function(x,y) touchDown(FID,x,y) end
  BE.move = function(x,y) touchMove(FID,x,y) end
  BE.up   = function(x,y) touchUp(FID,x,y) end
elseif hasXXTouch then
  BE.down = function(x,y) touch.on(x,y) end
  BE.move = function(x,y) touch.move(x,y) end
  BE.up   = function(x,y) touch.off(x,y) end
else
  BE.down = function() end; BE.move = function() end; BE.up = function() end
end

if type(usleep) == "function" then
  BE.sleep = function(ms) usleep(math.floor(ms*1000)) end
elseif type(sys)=="table" and type(sys.msleep)=="function" then
  BE.sleep = function(ms) sys.msleep(math.floor(ms)) end
elseif type(mSleep)=="function" then
  BE.sleep = function(ms) mSleep(math.floor(ms)) end
else
  BE.sleep = function(ms) local t=(os.clock and os.clock() or 0)+ms/1000; while os.clock and os.clock()<t do end end
end

if type(getColor)=="function" then
  BE.getColor1 = function(x,y) local c = getColor(x,y); return c end
elseif type(screen)=="table" and type(screen.get_color)=="function" then
  BE.getColor1 = function(x,y) local a,b,c = screen.get_color(x,y); if b and c then return a*0x10000+b*0x100+c end; return a end
else
  BE.getColor1 = function() return nil end
end

-- Đọc NHIỀU điểm trong 1 lời gọi native (điểm đã ở pixel thật).
if hasAutoTouch and type(getColors)=="function" then
  BE.getColors = function(pts)
    local res = getColors(pts)
    if type(res)=="table" then return res end
    local out={}; for i=1,#pts do out[i]=BE.getColor1(pts[i][1],pts[i][2]) end; return out
  end
else
  BE.getColors = function(pts)
    local out={}; for i=1,#pts do out[i]=BE.getColor1(pts[i][1],pts[i][2]) end; return out
  end
end

if type(getScreenResolution)=="function" then
  BE.screenSize = function() return getScreenResolution() end
elseif type(screen)=="table" and type(screen.size)=="function" then
  BE.screenSize = function() return screen.size() end
else
  BE.screenSize = function() return nil,nil end
end

local function toastMsg(m)
  if type(toast)=="function" then toast(m)
  elseif type(sys)=="table" and type(sys.toast)=="function" then sys.toast(m) end
end
local function logMsg(m)
  if type(log)=="function" then log(m)
  elseif type(nLog)=="function" then nLog(m)
  elseif type(print)=="function" then print(m) end
end
local function notify(m)
  toastMsg(tostring(m))
  if FEAT.verboseLog then logMsg("[AceBot] "..tostring(m)) end
end

-- ==========================================================================
-- SCALE + TAP/SWIPE/GIỮ-NHẢ + MÀU
-- ==========================================================================
local SX, SY = 1.0, 1.0
do
  local rw, rh = BE.screenSize()
  local w, h = BASE_W, BASE_H
  if rw and rh and rw>0 and rh>0 then w = math.min(rw,rh); h = math.max(rw,rh) end
  SX = w/BASE_W; SY = h/BASE_H
  if FEAT.verboseLog then logMsg(string.format("[AceBot] backend=%s scale=(%.3f,%.3f)",
    hasAutoTouch and "AutoTouch" or (hasXXTouch and "XXTouch" or "unknown"), SX, SY)) end
end
local function sx(x) return math.floor(x*SX+0.5) end
local function sy(y) return math.floor(y*SY+0.5) end

local function sleepMs(ms) BE.sleep(ms) end

local function tap(x,y,hold)
  hold = hold or TIME.tapDown
  local px,py = sx(x),sy(y)
  BE.down(px,py); sleepMs(hold); BE.up(px,py)
end
local function press(x,y) BE.down(sx(x),sy(y)) end
local function release(x,y) BE.up(sx(x),sy(y)) end

local function swipe(x1,y1,x2,y2,dur,steps)
  steps = steps or 12; dur = dur or 200
  local ax1,ay1 = sx(x1),sy(y1)
  local ax2,ay2 = sx(x2),sy(y2)
  local st = dur/steps
  BE.down(ax1,ay1); sleepMs(st)
  for i=1,steps do local t=i/steps
    BE.move(math.floor(ax1+(ax2-ax1)*t+0.5), math.floor(ay1+(ay2-ay1)*t+0.5)); sleepMs(st)
  end
  BE.up(ax2,ay2)
end

local function rgb(c)
  local r=math.floor(c/0x10000)%0x100
  local g=math.floor(c/0x100)%0x100
  local b=c%0x100
  return r,g,b
end
local function colorMatch(c1,c2,tol)
  if not c1 or not c2 then return false end
  tol = tol or 20
  local r1,g1,b1 = rgb(c1); local r2,g2,b2 = rgb(c2)
  return math.abs(r1-r2)<=tol and math.abs(g1-g2)<=tol and math.abs(b1-b2)<=tol
end
local function anchorActive(a)
  if not a then return false end
  return colorMatch(BE.getColor1(sx(a.x),sy(a.y)), a.color, a.tol)
end
local function waitAnchor(a, timeout, poll)
  timeout = timeout or 5000; poll = poll or 30
  local w=0
  while w<timeout do if anchorActive(a) then return true end; sleepMs(poll); w=w+poll end
  return false
end

-- Đọc nhiều điểm (hệ chuẩn -> tự scale) trong 1 getColors.
local function getColorsScaled(points)
  local sc={}; for i=1,#points do sc[i]={ sx(points[i][1]), sy(points[i][2]) } end
  return BE.getColors(sc)
end

-- Thanh lực: dựng điểm dò + suy ra % từ mảng màu.
local function makeTensionProbes(bar)
  local n = bar.probes or 28
  local pts={}
  for i=1,n do local t=(n>1) and ((i-1)/(n-1)) or 0
    pts[i]={ math.floor(bar.x0+(bar.x1-bar.x0)*t+0.5), bar.y } end
  return pts, n
end
local function tensionFromColors(cols, n, bar)
  local rb = bar.fillRB or 40; local minR = bar.fillMinR or 140
  local last=-1
  for i=1,n do local c=cols[i]
    if c then local r,g,b=rgb(c); if r>b+rb and r>minR then last=i end end
  end
  if last<0 then return 0,false end
  local pct=(n>1) and ((last-1)/(n-1)*100) or 0
  return pct,true
end
local function measureTensionPct(bar)
  local pts,n = makeTensionProbes(bar)
  return tensionFromColors(getColorsScaled(pts), n, bar)
end

-- ==========================================================================
-- BẢNG CẤU HÌNH (gọi dialog PHÒNG THỦ; hỏng thì dùng RUN mặc định)
-- ==========================================================================
local function toBoolV(v)
  if type(v)=="boolean" then return v end
  if type(v)=="number" then return v~=0 end
  if type(v)=="string" then v=v:lower(); return v=="1" or v=="true" or v=="on" or v=="yes" end
  return false
end
local function toCountV(v) local n=tonumber(v); if not n or n<0 then n=0 end; return math.floor(n) end
local function valByKey(cs,k) for _,c in ipairs(cs) do if c.key==k then return c.value end end end

local function showConfig()
  local defP = RUN.perfectCast and 1 or 0
  local defC = tostring(RUN.targetCount or 0)
  local function fb() return { perfectCast=toBoolV(defP), targetCount=toCountV(defC), ok=true } end

  if type(dialog)~="function" or type(CONTROLLER_TYPE)~="table" then
    logMsg("[ui] khong co dialog -> dung mac dinh"); return fb()
  end

  local controls = {
    { type=CONTROLLER_TYPE.LABEL,  text="Ace Fishing - Cau hinh" },
    { type=CONTROLLER_TYPE.SWITCH, key="perfect", title="Canh Perfect", value=defP },
    { type=CONTROLLER_TYPE.INPUT,  key="count",   title="So ca can cau (0 = vo han)", value=defC },
    { type=CONTROLLER_TYPE.BUTTON, title="Bat dau", color=0x1E90FF, flag=1, collectInputs=true },
    { type=CONTROLLER_TYPE.BUTTON, title="Huy",     color=0x8E8E93, flag=2, collectInputs=false },
  }

  local oriTable, oriNum
  if type(ORIENTATION_TYPE)=="table" and ORIENTATION_TYPE.PORTRAIT~=nil then
    oriTable={ ORIENTATION_TYPE.PORTRAIT }; oriNum=ORIENTATION_TYPE.PORTRAIT
  else oriTable={1}; oriNum=1 end

  local attempts = {
    function() return dialog(controls, oriTable) end,  -- orientations là BẢNG (AutoTouch 8.x)
    function() return dialog(controls, oriNum)   end,  -- orientations là SỐ
    function() return dialog(controls)           end,  -- không truyền orientations
  }
  local called, result, lastErr = false, nil, nil
  for i=1,#attempts do
    local okc, res = pcall(attempts[i])
    if okc then called=true; result=res; break else lastErr=res; logMsg("[ui] dialog#"..i.." loi: "..tostring(res)) end
  end
  if not called then logMsg("[ui] dialog hong het -> mac dinh: "..tostring(lastErr)); return fb() end

  local ok=true; if type(result)=="number" then ok=(result==1) end
  return { perfectCast=toBoolV(valByKey(controls,"perfect")), targetCount=toCountV(valByKey(controls,"count")), ok=ok }
end

-- ==========================================================================
-- MÁY TRẠNG THÁI CÂU CÁ
-- ==========================================================================
local STATE = { CAST="CAST", WAIT="WAIT", FIGHT="FIGHT", FINISH="FINISH", DISMISS="DISMISS" }
local running = true
local catches = 0
local dismissStreak = 0   -- chặn bấm "<" liên tục làm thoát khu câu

-- DEBUG: ghi màu thật tại điểm để hiệu chỉnh (không dùng màu nút nhấp nháy).
local DEBUG = true
local function hexc(c) if not c then return "nil" end local r,g,b=rgb(c); return string.format("0x%02X%02X%02X(r%d g%d b%d)",r,g,b,r,g,b) end
local function readAt(x,y) return BE.getColor1(sx(x), sy(y)) end

-- Chờ gauge teal HIỆN, tối đa maxMs. Trả true nếu thấy.
local function waitGaugeOn(maxMs)
  local w=0; local lastLog=-1000
  while w < maxMs do
    if anchorActive(ANCH.gaugeTarget) then return true end
    if DEBUG and (w-lastLog)>=400 then lastLog=w
      logMsg("[dbg] gauge("..ANCH.gaugeTarget.x..","..ANCH.gaugeTarget.y..")="..hexc(readAt(ANCH.gaugeTarget.x,ANCH.gaugeTarget.y)).." kyvong 0x5E9999")
    end
    sleepMs(40); w=w+40
  end
  return false
end

-- Chờ gauge teal TẮT, tối đa maxMs. Trả true nếu đã tắt (= cast đã ăn).
local function waitGaugeOff(maxMs)
  local w=0
  while w < maxMs do
    if not anchorActive(ANCH.gaugeTarget) then return true end
    sleepMs(40); w=w+40
  end
  return false
end

-- QUĂNG kiểu AutoJS, CÓ XÁC NHẬN:
--   1) MỞ: bấm START tới khi vòng cung teal HIỆN (thử vài lần).
--   2) CHỐT: canh perfect rồi tap; XÁC NHẬN cast đã ăn = vòng cung TẮT. Chưa tắt
--      thì tap lại. Nhờ vậy biết chắc "đã quăng được cần" mới vào kéo.
local function doCast()
  notify("Quang can...")

  -- 1) MỞ vòng cung
  local opened=false
  for t=1,4 do
    tap(COORDS.startButton.x, COORDS.startButton.y)
    if waitGaugeOn(1200) then opened=true; break end
    logMsg("[cast] START lan "..t..": chua thay vong cung, thu lai")
  end
  if not opened then
    logMsg("[cast] khong mo duoc vong cung -> co the o man ket qua/menu")
    return STATE.DISMISS
  end
  dismissStreak = 0
  logMsg("[cast] vong cung teal HIEN -> canh chot")

  -- 2) CHỐT lực + XÁC NHẬN cast đã ăn (vòng cung tắt)
  local casted=false
  for t=1,4 do
    if RUN.perfectCast and t==1 then
      -- canh kim VÀNG về tâm (chỉ ở lần chốt đầu)
      local hit=false; local pw=0; local plog=-1000
      while pw < TIME.perfectMax do
        if anchorActive(ANCH.castPerfect) then hit=true; break end
        if not anchorActive(ANCH.gaugeTarget) then break end
        if DEBUG and (pw-plog)>=300 then plog=pw
          logMsg("[dbg] needle("..ANCH.castPerfect.x..","..ANCH.castPerfect.y..")="..hexc(readAt(ANCH.castPerfect.x,ANCH.castPerfect.y)).." kyvong 0xF2D515")
        end
        sleepMs(15); pw=pw+15
      end
      notify(hit and "Chot PERFECT!" or "Chot thuong (het gio canh)")
    end
    tap(COORDS.castTapPoint.x, COORDS.castTapPoint.y)
    if waitGaugeOff(1500) then casted=true; break end
    logMsg("[cast] chot lan "..t..": vong cung CHUA tat, tap lai")
  end

  if not casted then
    notify("Quang KHONG an (vong cung con) -> thu lai")
    return STATE.CAST
  end
  notify("Da quang can OK -> keo ca")
  return STATE.FIGHT
end

local function waitForBite()
  notify("Cho ca can cau...")
  if not FEAT.useColorDetection then sleepMs(TIME.afterCastWaitMax/4); return STATE.FIGHT end
  local w=0
  while w<TIME.afterCastWaitMax do
    local pct,ok = measureTensionPct(TBAR)
    if ok and pct>TEN.hookedPct then notify("Ca da can cau!"); return STATE.FIGHT end
    sleepMs(30); w=w+30
  end
  notify("Het gio cho - quang lai.")
  return STATE.DISMISS
end

local function fightFish()
  notify("Bat dau keo ca!")
  -- Thời gian trận cộng dồn từ sleep (AutoTouch không có đồng hồ ms tin cậy).
  local elapsed=0
  local holding=false
  local releaseAt=0
  local holdSince=0
  local hooked=false
  local lastSeen=0

  -- Dựng điểm dò 1 lần: thanh lực + reward + nội lực; mỗi vòng 1 getColors.
  local probes, N = makeTensionProbes(TBAR)
  local iReward = N+1; probes[iReward] = { ANCH.rewardScreen.x, ANCH.rewardScreen.y }
  local iIP     = N+2; probes[iIP]     = { ANCH.innerPowerReady.x, ANCH.innerPowerReady.y }

  local function rel() if holding then release(COORDS.reelButton.x, COORDS.reelButton.y); holding=false end end
  local function hold() if not holding then press(COORDS.reelButton.x, COORDS.reelButton.y); holding=true; holdSince=elapsed end end

  while elapsed < TIME.fightTimeout do
    local cols = getColorsScaled(probes)
    local pct, ok = tensionFromColors(cols, N, TBAR)
    local rewardUp = FEAT.useColorDetection and colorMatch(cols[iReward], ANCH.rewardScreen.color, ANCH.rewardScreen.tol)
    local ipReady  = FEAT.useInnerPower and colorMatch(cols[iIP], ANCH.innerPowerReady.color, ANCH.innerPowerReady.tol)

    if ok and pct>TEN.hookedPct then hooked=true; lastSeen=elapsed end

    if DEBUG and (elapsed % 700) < TIME.reelPoll then
      logMsg("[dbg] fight t="..elapsed.." tension="..math.floor(pct+0.5)
        .." ok="..tostring(ok).." hooked="..tostring(hooked).." hold="..tostring(holding))
    end

    if rewardUp then rel(); notify("Da keo ca xong."); return STATE.FINISH end
    if hooked and (elapsed-lastSeen)>1500 then rel(); notify("Mat tension - coi nhu xong."); return STATE.FINISH end
    if (not hooked) and elapsed>9000 then rel(); notify("Khong thay ca - ket thuc."); return STATE.FINISH end

    if ipReady and hooked then
      rel()
      local ip = COORDS.innerPowerSwipe
      swipe(ip.from.x, ip.from.y, ip.to.x, ip.to.y, ip.durationMs)
      sleepMs(60); elapsed = elapsed+60+ip.durationMs
      hold(); releaseAt=0
    end

    -- GHIM SÁT VẠCH ("chạm vạch liên tục"): mỗi vòng phản ứng ngay —
    --   tension >= vạch      -> NHẢ (tay lên) cho tụt tí
    --   tension <= vạch-band -> GIỮ (tay xuống) đẩy lên lại
    --   ở giữa               -> giữ nguyên (hysteresis chống rung)
    -- Vòng ~30ms nên đây là nhấp giữ/nhả liên tục ghim tension ngay vạch.
    if not hooked then
      hold()
    elseif ok then
      if pct >= TEN.armPct then rel()
      elseif pct <= TEN.armPct - TEN.rearmDrop then hold() end
    else
      hold()  -- mất đọc -> giữ để khỏi tụt
    end

    sleepMs(TIME.reelPoll); elapsed = elapsed + TIME.reelPoll
  end

  rel(); notify("Keo qua lau - xu ly ket thuc.")
  return STATE.FINISH
end

-- Câu xong. CHỈ bấm "<" khi ĐANG ở màn kết quả (dãy nút xanh đáy) -> tuyệt đối
-- không bấm "<" trên màn sẵn sàng (sẽ thoát khu câu). Chỉ đếm khi có màn kết quả.
-- XỬ LÝ CÁ ở màn kết quả: bấm theo ưu tiên Hội -> Thêm(Add) -> Bán, dừng ngay khi
-- màn kết quả biến mất (dãy nút xanh mất). Rồi chờ màn đóng hẳn (START sắp về).
local function disposeResult()
  local order = { {COORDS.btnHoi,"Hoi"}, {COORDS.btnThem,"Add"}, {COORDS.btnBan,"Ban"} }
  for _,b in ipairs(order) do
    if not anchorActive(ANCH.resultBtn) then break end
    tap(b[1].x, b[1].y); notify("Xu ly ca: nhan "..b[2])
    sleepMs(1200)
  end
  -- chờ màn kết quả đóng hẳn
  local w=0
  while w<3000 and anchorActive(ANCH.resultBtn) do sleepMs(150); w=w+150 end
end

local function finish()
  -- Chờ màn kết quả hiện (cá có animation kéo lên) tối đa ~3s.
  local w=0
  while w<3000 and not anchorActive(ANCH.resultBtn) do sleepMs(150); w=w+150 end
  if anchorActive(ANCH.resultBtn) then
    catches = catches + 1
    notify(string.format("Cau duoc! Tong: %d con", catches))
    disposeResult()   -- Hội -> Add -> Bán
    if RUN.targetCount>0 and catches>=RUN.targetCount then
      notify(string.format("Da du %d con - dung.", RUN.targetCount)); running=false
    end
  else
    notify("Ket thuc (khong thay man ket qua) - quang lai")
  end
  sleepMs(TIME.betweenFish)
  return STATE.CAST
end

-- Không mở được vòng cung. Nếu ĐANG ở màn kết quả (dãy nút xanh) -> xử lý cá
-- (Hội/Add/Bán) như finish. Nếu không phải -> chỉ chờ rồi thử quăng lại; kẹt quá
-- lâu -> DỪNG cho an toàn (không bao giờ bấm lung tung trên màn sẵn sàng).
local function dismiss()
  if anchorActive(ANCH.resultBtn) then
    disposeResult()
    dismissStreak = 0
  else
    dismissStreak = dismissStreak + 1
    sleepMs(500)
    if dismissStreak > 8 then
      notify("Khong quang duoc lau -> DUNG. Kiem tra toa do START / mau gauge teal.")
      running = false
    end
  end
  return STATE.CAST
end

-- ==========================================================================
-- VÀO CHƯƠNG TRÌNH — vòng lặp XÁC NHẬN BẰNG GAUGE (không đọc nút nhấp nháy)
-- ==========================================================================
local choice = showConfig()
if not choice.ok then notify("Da huy - khong chay."); return end
RUN.perfectCast = choice.perfectCast
RUN.targetCount = choice.targetCount

notify(string.format("=== Ace Fishing === Perfect=%s Muc tieu=%s",
  tostring(RUN.perfectCast), RUN.targetCount==0 and "vo han" or tostring(RUN.targetCount)))

if DEBUG then
  local rw,rh = BE.screenSize()
  logMsg("[dbg] res="..tostring(rw).."x"..tostring(rh)..string.format(" scale=%.3f", SX))
  local p,ok = measureTensionPct(TBAR)
  logMsg("[dbg] tension khoi dau = "..math.floor(p+0.5).." ok="..tostring(ok))
end

-- Bắt đầu bằng CAST: bấm START, nếu thấy gauge teal = đang ở màn sẵn sàng -> câu.
local state = STATE.CAST
while running do
  if state==STATE.CAST      then state=doCast()
  elseif state==STATE.WAIT  then state=waitForBite()
  elseif state==STATE.FIGHT then state=fightFish()
  elseif state==STATE.FINISH then state=finish()
  elseif state==STATE.DISMISS then state=dismiss()
  else notify("Trang thai la: "..tostring(state)); state=STATE.CAST end
  sleepMs(TIME.loopSleep)
end
notify("=== Dung bot. Tong ca: "..catches.." ===")
