#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
main.py — Auto câu cá Ace Fishing (iPhone 7 Plus) qua zxtouchrootless.
MỘT chu kỳ: START -> canh Perfect -> CHỐT -> KÉO (ghim vạch) -> xong. Chỉ dùng màu.

QUAN TRỌNG: mọi lỗi được GHI RA FILE 'ace_fishing_error.log' (cùng thư mục) để mở
bằng Filza khi không xem được Logs. Chạy:
    python3 main.py          # 1 chu kỳ
    python3 main.py calib     # chỉ in màu tại các điểm
"""
import sys, os, time, traceback

_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in dir() else os.getcwd()
def _dump(prefix):
    msg = prefix + "\n" + traceback.format_exc()
    for path in (os.path.join(_HERE, "ace_fishing_error.log"), "ace_fishing_error.log"):
        try:
            with open(path, "w") as f: f.write(msg)
            break
        except Exception:
            pass
    try:
        sys.stdout.write(msg); sys.stdout.flush()
    except Exception:
        pass

# ---- import zxtouch (lỗi hay gặp nhất: thiếu module) ----
try:
    from zxtouch.client import zxtouch
    from zxtouch.touchtypes import TOUCH_DOWN, TOUCH_MOVE, TOUCH_UP
except Exception:
    _dump("IMPORT ERROR: khong import duoc 'zxtouch'. Kiem tra module zxtouch co cạnh main.py / trong site-packages.")
    raise SystemExit(1)

# ==========================================================================
# CẤU HÌNH — toạ độ hệ video 1080x1920, màu 0-255 (đo thật từ video)
# ==========================================================================
REF_W, REF_H = 1080.0, 1920.0
P_START = (540, 1575)
P_REEL  = (540, 1590)
T_X0, T_X1, T_Y = 315, 1000, 115
GAUGE_TEAL = (535, 1180)
NEEDLE     = (550, 1180)

# ---- Nội lực (vuốt LÊN, mũi tên teal) + Giật cần (vuốt TRÁI/PHẢI, chevron TRẮNG) ----
USE_POWER = True   # nội lực: mũi tên teal chỉ LÊN
USE_JERK  = True   # giật cần: chevron trắng « / »
SWIPE_MS  = 140

ARROW_UP = (540, 950)   # mũi tên "P" teal chỉ LÊN (nội lực)

# Chevron TRẮNG ở giữa màn ~y870 (đo thật). « (trái): trắng dồn BÊN TRÁI;
# » (phải): trắng dồn BÊN PHẢI. So 2 dải để biết hướng.
CHEV_LEFT  = [(470, 850), (470, 890)]   # trắng khi « (vuốt trái)
CHEV_RIGHT = [(580, 850), (580, 890)]   # trắng khi » (vuốt phải)

# Cú vuốt tương ứng (from -> to)
SWIPE_UP_FROM,    SWIPE_UP_TO    = (540, 1440), (540, 880)
SWIPE_LEFT_FROM,  SWIPE_LEFT_TO  = (640, 900), (240, 900)
SWIPE_RIGHT_FROM, SWIPE_RIGHT_TO = (440, 900), (840, 900)

ARM_PCT, LOW_PCT = 99, 10
LOST_SEC, NOFISH_SEC, FIGHT_MAX = 1.2, 9.0, 60.0
GAUGE_WAIT, PERFECT_WAIT, CAST_OFF_WAIT = 2.5, 3.0, 1.5

PICK_SCALE = 1.0   # nếu calib thấy màu SAI hết -> đổi thành giá trị SCALE in ra lúc init

# ==========================================================================
# BIẾN TOÀN CỤC (gán khi connect)
# ==========================================================================
device = None
SW = SH = 1.0
SCALE = 1.0
_holding = False
_jit = 0

# --- Bộ phân tích linh hoạt cho API zxtouch (trả về tuple/dict tuỳ bản) ---
def _tonum(v):
    try: return float(v)          # nhận cả chuỗi "1242.000000"
    except Exception: return None

def _flatten(x):
    out = []
    if isinstance(x, (tuple, list)):
        for v in x: out.extend(_flatten(v))
    else:
        out.append(x)
    return out

def _find_dict(x):
    if isinstance(x, dict): return x
    if isinstance(x, (tuple, list)):
        for v in x:
            d = _find_dict(v)
            if d is not None: return d
    return None

def _parse_size(sz):
    d = _find_dict(sz)
    if d is not None and "width" in d:
        return float(d["width"]), float(d["height"])
    nums = sorted(n for n in (_tonum(v) for v in _flatten(sz)) if n is not None)
    if len(nums) >= 2:
        return nums[-2], nums[-1]
    raise ValueError("get_screen_size dinh dang la: " + repr(sz))

def _parse_color(res):
    d = _find_dict(res)
    if d is not None and "red" in d:
        return float(d["red"]), float(d["green"]), float(d["blue"])
    nums = [n for n in (_tonum(v) for v in _flatten(res)) if n is not None]
    if len(nums) >= 3:
        return nums[-3], nums[-2], nums[-1]
    return None

def connect():
    global device, SW, SH, SCALE
    device = zxtouch("127.0.0.1")
    _sz = device.get_screen_size()
    print("[init] get_screen_size raw =", repr(_sz))
    w, h = _parse_size(_sz)
    SW, SH = min(w, h), max(w, h)   # game dọc: width < height
    try:
        SCALE = float(device.get_screen_scale())
    except Exception:
        SCALE = 1.0
    print("[init] SW=%s SH=%s scale=%s" % (SW, SH, SCALE))

def X(px): return int(round(px / REF_W * SW))
def Y(py): return int(round(py / REF_H * SH))

# ==========================================================================
# ĐỌC MÀU
# ==========================================================================
_pick_logged = False
def pick(px, py):
    global _pick_logged
    res = device.pick_color(int(round(X(px) * PICK_SCALE)), int(round(Y(py) * PICK_SCALE)))
    if not _pick_logged:
        print("[init] pick_color raw =", repr(res)); _pick_logged = True
    return _parse_color(res)

def is_fill(px, py):
    c = pick(px, py)
    if not c: return False
    r, g, b = c
    return r > 150 and (r - b) > 40

def is_teal(px, py):
    c = pick(px, py)
    if not c: return False
    r, g, b = c
    return g > 110 and b > 110 and r < 135 and abs(g - b) < 45

def is_yellow(px, py):
    c = pick(px, py)
    if not c: return False
    r, g, b = c
    return r > 190 and g > 150 and b < 95

def arrow_teal(px, py):
    """Điểm sáng teal của mũi tên NỘI LỰC (chỉ LÊN). Nền nước tối; mũi tên teal
    (~135,176,180)."""
    c = pick(px, py)
    if not c: return False
    r, g, b = c
    return b > 150 and (b - r) > 25 and g > 140

def is_white(px, py):
    """Điểm TRẮNG của chevron giật cần (« / »)."""
    c = pick(px, py)
    if not c: return False
    r, g, b = c
    return r > 195 and g > 195 and b > 195 and (max(r, g, b) - min(r, g, b)) < 30

# ==========================================================================
# CHẠM / GIỮ - NHẢ
# ==========================================================================
def tap(px, py, ms=40):
    x, y = X(px), Y(py)
    device.touch(TOUCH_DOWN, 1, x, y)
    time.sleep(ms / 1000.0)
    device.touch(TOUCH_UP, 1, x, y)

def swipe(p1, p2, ms=SWIPE_MS, steps=10):
    """Vuốt từ p1 -> p2 (hệ 1080x1920)."""
    global _holding
    x1, y1 = X(p1[0]), Y(p1[1])
    x2, y2 = X(p2[0]), Y(p2[1])
    device.touch(TOUCH_DOWN, 1, x1, y1)
    for i in range(1, steps + 1):
        t = i / float(steps)
        device.touch(TOUCH_MOVE, 1, int(round(x1 + (x2 - x1) * t)), int(round(y1 + (y2 - y1) * t)))
        time.sleep(ms / 1000.0 / steps)
    device.touch(TOUCH_UP, 1, x2, y2)
    _holding = False   # vuốt tự nhả tay

def hold():
    global _holding
    if not _holding:
        device.touch(TOUCH_DOWN, 1, X(P_REEL[0]), Y(P_REEL[1]))
        _holding = True

def release():
    global _holding
    if _holding:
        device.touch(TOUCH_UP, 1, X(P_REEL[0]), Y(P_REEL[1]))
        _holding = False

def hold_keepalive():
    global _jit
    if _holding:
        _jit ^= 1
        device.touch(TOUCH_MOVE, 1, X(P_REEL[0]) + _jit, Y(P_REEL[1]))

def mark_x(): return T_X0 + (T_X1 - T_X0) * ARM_PCT / 100.0
def low_x():  return T_X0 + (T_X1 - T_X0) * LOW_PCT / 100.0
def gauge_on(): return is_teal(*GAUGE_TEAL)

# ==========================================================================
# 1) QUĂNG + CANH PERFECT
# ==========================================================================
def do_cast():
    print("[cast] bam START")
    tap(*P_START)

    t0 = time.time()
    while time.time() - t0 < GAUGE_WAIT:
        if gauge_on(): break
        time.sleep(0.02)
    else:
        print("[cast] KHONG thay vong cung -> bo luot")
        return False

    hit = False
    t0 = time.time()
    while time.time() - t0 < PERFECT_WAIT:
        if is_yellow(*NEEDLE): hit = True; break
        if not gauge_on(): break
        time.sleep(0.006)
    tap(*P_START)
    print("[cast] chot", "PERFECT" if hit else "thuong")

    t0 = time.time()
    while time.time() - t0 < CAST_OFF_WAIT:
        if not gauge_on():
            print("[cast] da quang can OK"); return True
        time.sleep(0.02)
    print("[cast] vong cung con -> co the chua quang")
    return True

# ==========================================================================
# 2) KÉO CÁ — GHIM SÁT VẠCH
# ==========================================================================
def fight():
    print("[fight] bat dau keo")
    mx, my = mark_x(), T_Y
    lx = low_x()
    hooked = False
    last_seen = time.time()
    last_power = 0.0
    last_arrow = 0.0
    t0 = time.time()

    while time.time() - t0 < FIGHT_MAX:
        at_mark = is_fill(mx, my)              # tension đã chạm vạch (ARM_PCT) chưa
        present = at_mark or is_fill(lx, my)   # còn tension (còn cá) không
        if present:
            hooked = True; last_seen = time.time()

        if hooked and (time.time() - last_seen) > LOST_SEC:
            release(); print("[fight] mat tension -> ca da len"); return True
        if (not hooked) and (time.time() - t0) > NOFISH_SEC:
            release(); print("[fight] khong dinh ca"); return True

        # MŨI TÊN (throttle ~50ms để không làm chậm vòng ghim vạch):
        #   nội lực = teal chỉ LÊN | giật cần = chevron TRẮNG « (trái) / » (phải).
        if hooked and (time.time() - last_arrow) > 0.05 and (time.time() - last_power) > 0.5:
            last_arrow = time.time()
            up = USE_POWER and arrow_teal(*ARROW_UP)
            lw = sum(1 for p in CHEV_LEFT  if is_white(*p)) if USE_JERK else 0
            rw = sum(1 for p in CHEV_RIGHT if is_white(*p)) if USE_JERK else 0
            direction = None
            if up:                    direction = "up"
            elif lw >= 1 and rw == 0: direction = "left"
            elif rw >= 1 and lw == 0: direction = "right"
            if direction:
                if DEBUG: print("[dbg] arrow=%s up=%s lw=%d rw=%d" % (direction, up, lw, rw))
                release()
                if direction == "up":
                    print("[fight] NOI LUC -> vuot LEN"); swipe(SWIPE_UP_FROM, SWIPE_UP_TO)
                elif direction == "left":
                    print("[fight] GIAT can -> vuot TRAI"); swipe(SWIPE_LEFT_FROM, SWIPE_LEFT_TO)
                else:
                    print("[fight] GIAT can -> vuot PHAI"); swipe(SWIPE_RIGHT_FROM, SWIPE_RIGHT_TO)
                last_power = time.time()
                time.sleep(0.08)
                continue

        # GIỮ LIÊN TỤC khi dưới vạch (1 lần TOUCH_DOWN, KHÔNG rung) -> tension leo
        # tới vạch; chạm vạch -> NHẢ cho tụt. Không dùng keepalive (gây hiểu nhầm vuốt).
        if at_mark and hooked:
            release()
        else:
            hold()

        time.sleep(0.02)

    release(); print("[fight] qua gio"); return True

# ==========================================================================
# CALIB
# ==========================================================================
def calib():
    pts = {
        "START": P_START, "REEL": P_REEL,
        "GAUGE_TEAL": GAUGE_TEAL, "NEEDLE": NEEDLE,
        "T_x0": (T_X0, T_Y), "T_mark": (int(mark_x()), T_Y),
        "T_x1": (T_X1, T_Y), "T_low": (int(low_x()), T_Y),
    }
    print("=== CALIB (mau tai cac diem) ===")
    for name, (px, py) in pts.items():
        c = pick(px, py)
        print("  %-12s ref(%4d,%4d) pt(%4d,%4d) rgb=%s" % (name, px, py, X(px), Y(py), c))

def one_cycle():
    print("=== MOT CHU KY CAU CA ===")
    if not do_cast(): return
    fight()
    print("=== xong 1 chu ky ===")

SHOW_CALIB = True   # đặt False khi đã canh xong (bớt log)

def main():
    connect()
    if len(sys.argv) > 1 and sys.argv[1] == "calib":
        calib(); return
    if SHOW_CALIB:
        calib()      # in màu 1 lần để đối chiếu/hiệu chỉnh rồi mới câu
    one_cycle()

if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:
        _dump("RUNTIME ERROR (khi chay):")
    finally:
        try: release()
        except Exception: pass
        try:
            if device is not None: device.disconnect()
        except Exception: pass
