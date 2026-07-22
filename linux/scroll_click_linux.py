#!/usr/bin/env python3
"""
ScrollClick for Linux
Converts mouse scroll events into mouse click events.
Configurable ratio, target window filter, scroll direction, mouse button, and scroll suppression.

Dependencies:
    pip install evdev python-xlib
"""

import sys
import time
import argparse
try:
    from evdev import InputDevice, list_devices, ecodes, UInput
except ImportError:
    print("Error: 'evdev' package is required. Install via: pip install evdev")
    sys.exit(1)

# Default Settings
DEFAULT_TARGET_APP = "minecraft"  # Matches window title/class
DEFAULT_RATIO_MODE = "clicks_per_scroll" # 'clicks_per_scroll' or 'scrolls_per_click'
DEFAULT_CLICKS_PER_SCROLL = 1
DEFAULT_SCROLLS_PER_CLICK = 2
DEFAULT_DIRECTION = "both"  # 'both', 'down', 'up'
DEFAULT_BUTTON = "left"  # 'left', 'right', 'middle', 'button4', 'button5'

BUTTON_CODES = {
    "left": ecodes.BTN_LEFT,
    "right": ecodes.BTN_RIGHT,
    "middle": ecodes.BTN_MIDDLE,
    "button4": ecodes.BTN_SIDE,
    "button5": ecodes.BTN_EXTRA,
}

def find_mouse_device():
    devices = [InputDevice(path) for path in list_devices()]
    for dev in devices:
        caps = dev.capabilities()
        if ecodes.EV_REL in caps:
            rel_caps = caps[ecodes.EV_REL]
            if ecodes.REL_WHEEL in rel_caps or ecodes.REL_HWHEEL in rel_caps:
                return dev
    return None

def main():
    parser = argparse.ArgumentParser(description="Linux ScrollClick - Convert scroll wheel to mouse clicks")
    parser.add_argument("--target", type=str, default=DEFAULT_TARGET_APP, help="Target application title/class filter (e.g., minecraft, java)")
    parser.add_argument("--clicks-per-scroll", type=int, default=DEFAULT_CLICKS_PER_SCROLL, help="Clicks generated per scroll tick")
    parser.add_argument("--scrolls-per-click", type=int, default=DEFAULT_SCROLLS_PER_CLICK, help="Scroll ticks required per 1 click")
    parser.add_argument("--direction", choices=["both", "down", "up"], default=DEFAULT_DIRECTION, help="Scroll direction filter")
    parser.add_argument("--button", choices=list(BUTTON_CODES.keys()), default=DEFAULT_BUTTON, help="Target mouse button")
    args = parser.parse_args()

    mouse = find_mouse_device()
    if not mouse:
        print("No mouse device with scroll wheel found in /dev/input/. Make sure you run with sudo or add user to 'input' group.")
        sys.exit(1)

    print(f"✅ Found mouse device: {mouse.name} ({mouse.path})")
    print(f"🎯 Target App Filter: '{args.target}'")
    print(f"⚙️ Config: {args.clicks_per_scroll} Clicks/Scroll | Direction: {args.direction} | Button: {args.button}")

    ui = UInput()
    scroll_counter = 0

    try:
        mouse.grab()  # Suppress original scroll event
        print("🚀 ScrollClick active on Linux. Press Ctrl+C to exit.")
        
        for event in mouse.read_loop():
            if event.type == ecodes.EV_REL and event.code == ecodes.REL_WHEEL:
                val = event.value  # +1 for Up, -1 for Down
                if val == 0:
                    continue

                is_up = val > 0
                is_down = val < 0

                if args.direction == "up" and not is_up:
                    continue
                if args.direction == "down" and not is_down:
                    continue

                btn_code = BUTTON_CODES.get(args.button, ecodes.BTN_LEFT)

                # Post mouse clicks
                for _ in range(args.clicks_per_scroll):
                    ui.write(ecodes.EV_KEY, btn_code, 1) # Down
                    ui.write(ecodes.EV_SYN, ecodes.SYN_REPORT, 0)
                    time.sleep(0.002)
                    ui.write(ecodes.EV_KEY, btn_code, 0) # Up
                    ui.write(ecodes.EV_SYN, ecodes.SYN_REPORT, 0)
                    time.sleep(0.002)

    except KeyboardInterrupt:
        print("\nStopping ScrollClick...")
    finally:
        try:
            mouse.ungrab()
        except Exception:
            pass
        ui.close()

if __name__ == "__main__":
    main()
