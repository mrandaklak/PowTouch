#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ace_fishing.py — Auto câu cá Ace Fishing cho iPhone 7 Plus qua zxtouchrootless.
Học logic từ D:\\GAME\\AceFishing\\core\\fishing\\default.js.

PHIÊN BẢN NÀY: chạy ĐÚNG 1 CHU KỲ câu (chưa xử lý popup/kết quả):
    START -> canh Perfect -> CHỐT (xác nhận vòng cung tắt) -> KÉO (ghim vạch) -> xong.

Chỉ dùng MÀU (pick_color), không dùng image. Toạ độ & màu đo từ video màn hình
1080x1920, được scale theo tỉ lệ sang điểm màn thật (get_screen_size) nên đúng cho
mọi độ phân giải.

Tối ưu tốc độ: lúc kéo chỉ đọc 1-2 pixel/vòng (pick_color rất nhanh) để nhấp
"chạm vạch" liên tục với độ trễ thấp nhất.

CHẠY: đặt file cạnh module zxtouch (hoặc copy zxtouch vào site-packages), rồi:
    python3 ace_fishing.py          # chạy 1 chu kỳ
    python3 ace_fishing.py calib    # chỉ in màu tại các điểm để hiệu chỉnh
"""

import sys
import time

from zxtouch.client import zxtouch
from zxtouch.touchtypes import TOUCH_DOWN, TOUCH_MOVE, TOUCH_UP

# ==========================================================================
# CẤU HÌNH — toạ độ theo hệ video 1080x1920, màu 0-255 (đo thật từ video)
# ==========================================================================
REF_W, REF_H = 1080.0, 1920.0

P_START = (540, 1575)   # nút START (quăng cần) / cùng chỗ hiện "TAP" để chốt
P_REEL  = (540, 1590)   # nút reel/orb — giữ để kéo cá

# Thanh lực (tension) NGANG trên cùng: x0=0%, x1=100%(vạch "HIGH"/đứt), y=hàng bar
T_X0, T_X1, T_Y = 315, 1000, 115

GAUGE_TEAL = (535, 1180)  # vùng teal vòng cung (gauge đang hiện)
NEEDLE     = (550, 1180)  # kim VÀNG về tâm = thời điểm perfect

# ---- Cơ chế kéo (ghim sát vạch) ----
ARM_PCT    = 88   # vạch nhả: ghim tension quanh mức này (95 rất dễ đứt; 85-88 hợp lý)
LOW_PCT    = 10   # điểm thấp để biết "còn tension" (đang có cá)
LOST_SEC   = 1.2  # mất tension lâu hơn ngần này -> coi như cá đã lên
NOFISH_SEC = 9.0  # chưa dính cá sau ngần này -> thôi (an toàn)
FIGHT_MAX  = 60.0 # trần thời gian 1 trận

# ---- Thời gian canh cast ----
GAUGE_WAIT = 2.5  # chờ vòng cung hiện sau khi bấm START
PERFECT_WAIT = 3.0
CAST_OFF_WAIT = 1.5

# ==========================================================================
# KẾT NỐI + SCALE
# ==========================================================================
device = zxtouch("127.0.0.1")
_sz = device.get_screen_size()
SW = float(_sz["width"])
SH = float(_sz["height"])
try:
    SCALE = float(device.get_screen_scale())
except Exception:
    SCALE = 1.0
print("[init] screen size = %sx%s  scale = %s" % (_sz["width"], _sz["height"], SCALE))

# touch dùng POINTS (theo get_screen_size).
def X(px): return int(round(px / REF_W * SW))
def Y(py): return int(round(py / REF_H * SH))

# pick_color: MỘT SỐ bản zxtouch đọc màu theo PIXEL (ảnh render = points*scale),
# số khác theo POINTS. Nếu chạy `calib` thấy màu SAI hết -> đổi PICK_SCALE:
#   PICK_SCALE = 1.0    -> pick theo points (giống touch)
#   PICK_SCALE = SCALE  -> pick theo pixel render (points * scale)
PICK_SCALE = 1.0

# ==========================================================================
# ĐỌC MÀU
# ==========================================================================
def pick(px, py):
    """Trả (r,g,b) tại điểm theo hệ 1080x1920, hoặc None nếu lỗi."""
    ok, c = device.pick_color(int(round(X(px) * PICK_SCALE)), int(round(Y(py) * PICK_SCALE)))
    if ok:
        return c["red"], c["green"], c["blue"]
    return None

def is_fill(px, py):
    """Mép fill tension = cam/đỏ: đỏ trội hơn xanh dương và đủ sáng."""
    c = pick(px, py)
    if not c: return False
    r, g, b = c
    return r > 150 and (r - b) > 40

def is_teal(px, py):
    """Teal vòng cung: xanh lá + xanh dương cao, đỏ thấp."""
    c = pick(px, py)
    if not c: return False
    r, g, b = c
    return g > 110 and b > 110 and r < 135 and abs(g - b) < 45

def is_yellow(px, py):
    """Kim vàng: đỏ+lá cao, xanh dương thấp."""
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

_holding = False
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

_jit = 0
def hold_keepalive():
    """Giữ finger sống (gửi MOVE dịch 1px) để không bị coi là nhấp rời tay."""
    global _jit
    if _holding:
        _jit ^= 1
        device.touch(TOUCH_MOVE, 1, X(P_REEL[0]) + _jit, Y(P_REEL[1]))

def mark_x():
    return T_X0 + (T_X1 - T_X0) * ARM_PCT / 100.0

def low_x():
    return T_X0 + (T_X1 - T_X0) * LOW_PCT / 100.0

def gauge_on():
    return is_teal(*GAUGE_TEAL)

# ==========================================================================
# 1) QUĂNG + CANH PERFECT (xác nhận đã quăng bằng vòng cung tắt)
# ==========================================================================
def do_cast():
    print("[cast] bam START")
    tap(*P_START)

    # chờ vòng cung teal hiện
    t0 = time.time()
    while time.time() - t0 < GAUGE_WAIT:
        if gauge_on():
            break
        time.sleep(0.02)
    else:
        print("[cast] KHONG thay vong cung -> bo luot")
        return False

    # canh kim VÀNG về tâm rồi CHỐT
    hit = False
    t0 = time.time()
    while time.time() - t0 < PERFECT_WAIT:
        if is_yellow(*NEEDLE):
            hit = True
            break
        if not gauge_on():
            break
        time.sleep(0.006)
    tap(*P_START)
    print("[cast] chot", "PERFECT" if hit else "thuong")

    # xác nhận vòng cung TẮT = đã quăng cần
    t0 = time.time()
    while time.time() - t0 < CAST_OFF_WAIT:
        if not gauge_on():
            print("[cast] da quang can OK")
            return True
        time.sleep(0.02)
    print("[cast] vong cung con -> co the chua quang")
    return True  # vẫn thử vào kéo

# ==========================================================================
# 2) KÉO CÁ — GHIM SÁT VẠCH (đọc 1-2 pixel/vòng cho nhanh)
# ==========================================================================
def fight():
    print("[fight] bat dau keo")
    mx, my = mark_x(), T_Y
    lx = low_x()
    hooked = False
    last_seen = time.time()
    t0 = time.time()

    while time.time() - t0 < FIGHT_MAX:
        at_mark = is_fill(mx, my)              # tension đã chạm vạch chưa
        present = at_mark or is_fill(lx, my)   # còn tension (còn cá) không
        if present:
            hooked = True
            last_seen = time.time()

        # kết thúc
        if hooked and (time.time() - last_seen) > LOST_SEC:
            release()
            print("[fight] mat tension -> ca da len")
            return True
        if (not hooked) and (time.time() - t0) > NOFISH_SEC:
            release()
            print("[fight] khong dinh ca")
            return True

        # GHIM VẠCH: chạm vạch -> NHẢ; chưa chạm -> GIỮ (nhấp liên tục ngay vạch)
        if not hooked:
            hold()
        elif at_mark:
            release()
        else:
            hold()

        hold_keepalive()
        time.sleep(0.004)   # iPhone đọc nhanh -> vòng cực ngắn

    release()
    print("[fight] qua gio")
    return True

# ==========================================================================
# CALIB — in màu tại các điểm để đối chiếu/hiệu chỉnh
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

# ==========================================================================
def one_cycle():
    print("=== MOT CHU KY CAU CA ===")
    if not do_cast():
        return
    fight()
    print("=== xong 1 chu ky ===")

if __name__ == "__main__":
    try:
        if len(sys.argv) > 1 and sys.argv[1] == "calib":
            calib()
        else:
            one_cycle()
    finally:
        release()
        device.disconnect()
