#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
zx_test.py — kiem tra moi truong zxtouch. GHI ket qua ra file zx_test_result.txt
(cung thu muc) de mo bang Filza neu khong xem duoc Logs.
Chay:  python3 zx_test.py
"""
import sys, os, traceback

here = os.path.dirname(os.path.abspath(__file__)) if "__file__" in dir() else os.getcwd()
out = []
def line(s): out.append(str(s))

line("python: " + sys.version.replace("\n", " "))
line("cwd: " + os.getcwd())
line("script dir: " + here)
line("sys.path[0:3]: " + str(sys.path[0:3]))
line("-" * 40)

try:
    from zxtouch.client import zxtouch
    line("import zxtouch: OK")
    try:
        d = zxtouch("127.0.0.1")
        line("connect 127.0.0.1:6000: OK")
        try:
            line("get_screen_size: " + str(d.get_screen_size()))
        except Exception:
            line("get_screen_size FAIL:\n" + traceback.format_exc())
        try:
            line("get_screen_scale: " + str(d.get_screen_scale()))
        except Exception:
            line("get_screen_scale FAIL:\n" + traceback.format_exc())
        try:
            ok, c = d.pick_color(100, 100)
            line("pick_color(100,100): ok=%s color=%s" % (ok, c))
        except Exception:
            line("pick_color FAIL:\n" + traceback.format_exc())
        try:
            d.disconnect()
        except Exception:
            pass
    except Exception:
        line("connect FAIL (daemon chay chua? cong 6000?):\n" + traceback.format_exc())
except Exception:
    line("import zxtouch FAIL (thieu module 'zxtouch'):\n" + traceback.format_exc())

text = "\n".join(out)
try:
    with open(os.path.join(here, "zx_test_result.txt"), "w") as f:
        f.write(text)
except Exception:
    try:
        with open("zx_test_result.txt", "w") as f:
            f.write(text)
    except Exception:
        pass

print(text)
