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

ARM_PCT, LOW_PCT = 88, 10
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

def connect():
    global device, SW, SH, SCALE
    device = zxtouch("127.0.0.1")
    _sz = device.get_screen_size()
    SW = float(_sz["width"]); SH = float(_sz["height"])
    try:
        SCALE = float(device.get_screen_scale())
    except Exception:
        SCALE = 1.0
    print("[init] screen size = %sx%s  scale = %s" % (_sz["width"], _sz["height"], SCALE))

def X(px): return int(round(px / REF_W * SW))
def Y(py): return int(round(py / REF_H * SH))

# ==========================================================================
# ĐỌC MÀU
# ==========================================================================
def pick(px, py):
    ok, c = device.pick_color(int(round(X(px) * PICK_SCALE)), int(round(Y(py) * PICK_SCALE)))
    if ok:
        return c["red"], c["green"], c["blue"]
    return None

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

# ==========================================================================
# CHẠM / GIỮ - NHẢ
# ==========================================================================
def tap(px, py, ms=40):
    x, y = X(px), Y(py)
    device.touch(TOUCH_DOWN, 1, x, y)
    time.sleep(ms / 1000.0)
    device.touch(TOUCH_UP, 1, x, y)

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
    t0 = time.time()

    while time.time() - t0 < FIGHT_MAX:
        at_mark = is_fill(mx, my)
        present = at_mark or is_fill(lx, my)
        if present:
            hooked = True; last_seen = time.time()

        if hooked and (time.time() - last_seen) > LOST_SEC:
            release(); print("[fight] mat tension -> ca da len"); return True
        if (not hooked) and (time.time() - t0) > NOFISH_SEC:
            release(); print("[fight] khong dinh ca"); return True

        if not hooked:   hold()
        elif at_mark:    release()
        else:            hold()

        hold_keepalive()
        time.sleep(0.004)

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

def main():
    connect()
    if len(sys.argv) > 1 and sys.argv[1] == "calib":
        calib()
    else:
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
