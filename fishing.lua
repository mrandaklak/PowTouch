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

-- Toạ độ nút / vùng bấm (cần hiệu chỉnh)
local COORDS = {
  startButton   = { x = 540,  y = 1720 }, -- nút START (quăng cần)
  castTapPoint  = { x = 540,  y = 1720 }, -- điểm tap để CHỐT lực
  reelButton    = { x = 540,  y = 1660 }, -- nút reel/orb (giữ để kéo cá)
  innerPowerSwipe = { from = { x = 540, y = 1500 }, to = { x = 540, y = 1050 }, durationMs = 160 },
  confirmPoint  = { x = 540,  y = 1780 }, -- điểm đóng popup phần thưởng
}

-- Thanh lực (tension): x0=0%, x1=100%(vạch đứt), y=hàng giữa, probes=số điểm đọc/1 getColors
local TBAR = { x0 = 250, x1 = 830, y = 250, probes = 28, fillMinR = 150, fillRB = 40 }

-- Anchor màu: { x, y, color(0xRRGGBB), tol }
local ANCH = {
  ready           = { x = 540, y = 1720, color = 0x39C46B, tol = 26 }, -- màn sẵn sàng (START xanh)
  gaugeTarget     = { x = 540, y = 1500, color = 0x27D3C4, tol = 34 }, -- ô đích teal (gauge đang hiện)
  castPerfect     = { x = 540, y = 1500, color = 0xFFD200, tol = 30 }, -- kim vàng đè ô đích
  innerPowerReady = { x = 300, y = 300,  color = 0x00E0FF, tol = 34 }, -- thanh nội lực đầy
  rewardScreen    = { x = 540, y = 400,  color = 0xFFFFFF, tol = 24 }, -- màn phần thưởng
}

-- Cơ chế giữ–nhả tension
local TEN = { armPct = 78, rearmDrop = 8, releaseMs = 90, minHoldMs = 70, hookedPct = 6 }

-- Thời gian (ms)
local TIME = {
  loopSleep = 40, tapDown = 30, reelPoll = 30,
  castGaugeTimeout = 6000, perfectMax = 4000,
  afterCastWaitMax = 18000, fightTimeout = 60000, betweenFish = 1200,
}

local FEAT = { useColorDetection = true, useInnerPower = true, autoConfirmReward = true, verboseLog = true }

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
local STATE = { READY="READY", CAST="CAST", WAIT="WAIT", FIGHT="FIGHT", FINISH="FINISH" }
local running = true
local catches = 0

local function doCast()
  notify("Quang can...")
  tap(COORDS.startButton.x, COORDS.startButton.y)

  if not FEAT.useColorDetection then
    sleepMs(TIME.castGaugeTimeout/2)
    tap(COORDS.castTapPoint.x, COORDS.castTapPoint.y)
    return STATE.WAIT
  end

  if not waitAnchor(ANCH.gaugeTarget, TIME.castGaugeTimeout, 20) then
    notify("Khong thay vong cung luc, thu lai.")
    return STATE.READY
  end

  if RUN.perfectCast then
    local hit = waitAnchor(ANCH.castPerfect, TIME.perfectMax, 8)
    tap(COORDS.castTapPoint.x, COORDS.castTapPoint.y)
    notify(hit and "Chot luc PERFECT!" or "Het gio canh - chot thuong.")
  else
    tap(COORDS.castTapPoint.x, COORDS.castTapPoint.y)
    notify("Quang thuong.")
  end
  return STATE.WAIT
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
  return STATE.READY
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

    if rewardUp then rel(); notify("Da keo ca xong."); return STATE.FINISH end
    if hooked and (elapsed-lastSeen)>1500 then rel(); notify("Mat tension - coi nhu xong."); return STATE.FINISH end

    if ipReady and hooked then
      rel()
      local ip = COORDS.innerPowerSwipe
      swipe(ip.from.x, ip.from.y, ip.to.x, ip.to.y, ip.durationMs)
      sleepMs(60); elapsed = elapsed+60+ip.durationMs
      hold(); releaseAt=0
    end

    if not hooked then
      hold()
    elseif holding then
      if ok and pct>=TEN.armPct and (elapsed-holdSince)>=TEN.minHoldMs then
        rel(); releaseAt = elapsed + TEN.releaseMs
      end
    else
      if elapsed>=releaseAt and (not ok or pct<=TEN.armPct-TEN.rearmDrop) then hold() end
    end

    sleepMs(TIME.reelPoll); elapsed = elapsed + TIME.reelPoll
  end

  rel(); notify("Keo qua lau - xu ly ket thuc.")
  return STATE.FINISH
end

local function finish()
  catches = catches + 1
  notify(string.format("Cau xong! Tong: %d con", catches))
  if FEAT.autoConfirmReward then
    for _=1,5 do
      tap(COORDS.confirmPoint.x, COORDS.confirmPoint.y)
      sleepMs(400)
      if FEAT.useColorDetection and anchorActive(ANCH.ready) then break end
    end
  end
  if RUN.targetCount>0 and catches>=RUN.targetCount then
    notify(string.format("Da du %d con - dung.", RUN.targetCount)); running=false
  end
  sleepMs(TIME.betweenFish)
  return STATE.READY
end

-- ==========================================================================
-- VÀO CHƯƠNG TRÌNH
-- ==========================================================================
local choice = showConfig()
if not choice.ok then notify("Da huy - khong chay."); return end
RUN.perfectCast = choice.perfectCast
RUN.targetCount = choice.targetCount

notify(string.format("=== Ace Fishing === Perfect=%s Muc tieu=%s",
  tostring(RUN.perfectCast), RUN.targetCount==0 and "vo han" or tostring(RUN.targetCount)))

local state = STATE.READY
while running do
  if state==STATE.READY then
    if FEAT.useColorDetection and not anchorActive(ANCH.ready) then sleepMs(TIME.loopSleep)
    else state=STATE.CAST end
  elseif state==STATE.CAST   then state=doCast()
  elseif state==STATE.WAIT   then state=waitForBite()
  elseif state==STATE.FIGHT  then state=fightFish()
  elseif state==STATE.FINISH then state=finish()
  else notify("Trang thai la: "..tostring(state)); state=STATE.READY end
  sleepMs(TIME.loopSleep)
end
notify("=== Dung bot. Tong ca: "..catches.." ===")
