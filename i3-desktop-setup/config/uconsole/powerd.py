#!/usr/bin/env python3
"""uconsole-powerd — power-button watcher for the uConsole deep-sleep.

Reads the power button straight from /dev/input, so it still sees presses while
i3lock holds the X keyboard grab (where an i3 keybinding would not fire). On a
short press it runs `uconsole-sleep` (which toggles the deep low-power state);
long presses are left to logind (poweroff).

Needs python3-evdev and the user in the "input" group.
"""
import subprocess
import sys
import time

try:
    import evdev
    from evdev import ecodes
except Exception as exc:  # noqa: BLE001
    sys.stderr.write("uconsole-powerd: python3-evdev not available: %s\n" % exc)
    sys.exit(1)

SHORT_MAX = 1.2  # seconds; a longer hold is a "long press" -> leave it to logind


def find_power_device():
    for path in evdev.list_devices():
        try:
            dev = evdev.InputDevice(path)
        except Exception:  # noqa: BLE001
            continue
        if ecodes.KEY_POWER in dev.capabilities().get(ecodes.EV_KEY, []):
            return dev
    return None


def main():
    dev = find_power_device()
    if dev is None:
        sys.stderr.write("uconsole-powerd: no KEY_POWER input device found\n")
        sys.exit(1)
    sys.stderr.write("uconsole-powerd: watching %s (%s)\n" % (dev.path, dev.name))

    pressed_at = None
    for event in dev.read_loop():
        if event.type != ecodes.EV_KEY or event.code != ecodes.KEY_POWER:
            continue
        if event.value == 1:            # key down
            pressed_at = time.time()
        elif event.value == 0:          # key up
            if pressed_at is not None and (time.time() - pressed_at) < SHORT_MAX:
                subprocess.Popen(["uconsole-sleep"])
            pressed_at = None


if __name__ == "__main__":
    main()
