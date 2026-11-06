#!/usr/bin/env python3
"""Offline checks for Scripts/pick_simulator.py (no macOS required)."""

import io
import json
import subprocess
import sys
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("pick_simulator.py")


def run(payload):
    return subprocess.run(
        [sys.executable, str(SCRIPT)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
    )


def fixture(devices):
    return {"devices": devices}


IOS_17 = "com.apple.CoreSimulator.SimRuntime.iOS-17-0"
IOS_18 = "com.apple.CoreSimulator.SimRuntime.iOS-18-0"
WATCH = "com.apple.CoreSimulator.SimRuntime.watchOS-11-0"


class PickSimulatorTests(unittest.TestCase):

    def test_prefers_named_device_over_an_unknown_phone(self):
        result = run(fixture({
            IOS_18: [
                {"name": "iPhone 17", "udid": "OTHER", "isAvailable": True},
                {"name": "iPhone 16", "udid": "WANTED", "isAvailable": True},
            ]
        }))
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "WANTED")

    def test_prefers_the_newest_runtime_for_the_same_name(self):
        result = run(fixture({
            IOS_17: [{"name": "iPhone 16", "udid": "OLD", "isAvailable": True}],
            IOS_18: [{"name": "iPhone 16", "udid": "NEW", "isAvailable": True}],
        }))
        self.assertEqual(result.stdout.strip(), "NEW")

    def test_falls_back_to_any_iphone_when_no_preferred_name_exists(self):
        result = run(fixture({
            IOS_18: [{"name": "iPhone 99", "udid": "FALLBACK", "isAvailable": True}],
        }))
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "FALLBACK")

    def test_ignores_unavailable_devices_and_non_ios_runtimes(self):
        result = run(fixture({
            IOS_18: [
                {"name": "iPhone 15", "udid": "UNAVAILABLE", "isAvailable": False},
                {"name": "iPhone 14", "udid": "USABLE", "isAvailable": True},
            ],
            WATCH: [{"name": "iPhone 13", "udid": "WATCHISH", "isAvailable": True}],
        }))
        self.assertEqual(result.stdout.strip(), "USABLE")

    def test_reports_failure_when_nothing_is_available(self):
        result = run(fixture({IOS_18: []}))
        self.assertEqual(result.returncode, 1)
        self.assertIn("no available iPhone simulator", result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
