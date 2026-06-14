#!/usr/bin/env python3
"""uconsole-powerd — power-button watcher for the uConsole deep-sleep.

Runs `uconsole-sleep` on a power-button press (toggles the deep low-power state).
Reads /dev/input directly, so it works through i3lock's keyboard grab. Triggers
on the key *press* (some power buttons send no release event) with a short
debounce, and watches every device that exposes a power/sleep key.

Debugging: run it in a terminal and press the button — it logs the device it
watches and every detected press.

Needs python3-evdev and the user in the "input" group.
"""
import selectors
import subprocess
import sys
import time

try:
    import evdev
    from evdev import ecodes
except Exception as exc:  # noqa: BLE001
    sys.stderr.write("uconsole-powerd: python3-evdev not available: %s\n" % exc)
    sys.exit(1)

POWER_KEYS = {getattr(ecodes, n) for n in ("KEY_POWER", "KEY_SLEEP", "KEY_SUSPEND")
              if hasattr(ecodes, n)}
DEBOUNCE = 0.8  # seconds between accepted presses


def power_devices():
    found = []
    for path in evdev.list_devices():
        try:
            dev = evdev.InputDevice(path)
        except Exception:  # noqa: BLE001
            continue
        keys = set(dev.capabilities().get(ecodes.EV_KEY, []))
        if keys & POWER_KEYS:
            found.append(dev)
    return found


def main():
    devices = power_devices()
    if not devices:
        sys.stderr.write("uconsole-powerd: no power/sleep-key input device found "
                         "(is the user in the 'input' group? what does the button emit?)\n")
        sys.exit(1)

    sel = selectors.DefaultSelector()
    for dev in devices:
        sys.stderr.write("uconsole-powerd: watching %s (%s)\n" % (dev.path, dev.name))
        sel.register(dev, selectors.EVENT_READ)

    last = 0.0
    while True:
        for key, _ in sel.select():
            try:
                events = list(key.fileobj.read())
            except OSError:
                continue
            for ev in events:
                if ev.type == ecodes.EV_KEY and ev.code in POWER_KEYS and ev.value == 1:
                    now = time.time()
                    if now - last < DEBOUNCE:
                        continue
                    last = now
                    sys.stderr.write("uconsole-powerd: power key pressed -> uconsole-sleep\n")
                    sys.stderr.flush()
                    subprocess.Popen(["uconsole-sleep"])


if __name__ == "__main__":
    main()
