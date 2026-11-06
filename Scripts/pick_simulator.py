#!/usr/bin/env python3
"""Print the UDID of the best available iPhone simulator.

Reads `xcrun simctl list devices available -j` from stdin.

A hardcoded `name=iPhone 16` destination breaks whenever a runner image drops
that exact device, so the destination is resolved from the machine instead:
the newest iOS runtime wins, and within it a preferred device name is chosen.
Exits with status 1 when no iPhone simulator is available.
"""

import json
import sys

RUNTIME_PREFIX = "com.apple.CoreSimulator.SimRuntime.iOS-"

PREFERRED = (
    "iPhone 16",
    "iPhone 16 Pro",
    "iPhone 15",
    "iPhone 15 Pro",
    "iPhone 14",
    "iPhone SE (3rd generation)",
)


def main() -> int:
    payload = json.load(sys.stdin)
    by_name = {}

    for runtime, devices in payload["devices"].items():
        if not runtime.startswith(RUNTIME_PREFIX):
            continue
        for device in devices:
            if not device.get("isAvailable") or "iPhone" not in device["name"]:
                continue
            previous = by_name.get(device["name"])
            if previous is None or runtime > previous[0]:
                by_name[device["name"]] = (runtime, device["udid"])

    for name in PREFERRED:
        if name in by_name:
            print(by_name[name][1])
            return 0

    if by_name:
        print(max(by_name.values())[1])
        return 0

    print("no available iPhone simulator", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
