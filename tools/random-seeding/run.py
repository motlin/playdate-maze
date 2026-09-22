#!/usr/bin/env python3
"""Compare initial RNG sequences in separate macOS Simulator processes."""

import argparse
import datetime
import json
import os
from pathlib import Path
import platform
import plistlib
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs", type=int, default=5)
    parser.add_argument("--sdk", type=Path, default=Path(os.environ.get("PLAYDATE_SDK_PATH", Path.home() / "Developer/PlaydateSDK")))
    arguments = parser.parse_args()
    if arguments.runs < 2:
        parser.error("--runs must be at least 2")
    root = Path(__file__).resolve().parents[2]
    output = root / "builds/random-seeding"
    output.mkdir(parents=True, exist_ok=True)
    bundle = output / "RandomSeedDiagnostic.pdx"
    simulator = arguments.sdk / "bin/Playdate Simulator.app"
    subprocess.run([str(arguments.sdk / "bin/pdc"), "--skip-unknown", str(root / "tools/random-seeding"), str(bundle)], check=True)
    with (simulator / "Contents/Info.plist").open("rb") as file:
        version = plistlib.load(file)
    result = {
        "recorded_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "host": platform.platform(),
        "sdk": (arguments.sdk / "VERSION.txt").read_text().strip(),
        "simulator_version": version["CFBundleShortVersionString"],
        "simulator_build": version["CFBundleVersion"],
        "launch_method": "One new Simulator executable process per sample, exits after startup",
        "random_calls": "12 consecutive math.random(1, 1000000) calls before imports or game code",
        "samples": [],
    }
    for launch in range(1, arguments.runs + 1):
        for mode in ("omitted", "explicit", "fixed"):
            command = [str(simulator / "Contents/MacOS/Playdate Simulator"), str(bundle), mode]
            completed = subprocess.run(command, capture_output=True, text=True, timeout=45)
            (output / f"{mode}-{launch}.log").write_text(completed.stdout + completed.stderr)
            completed.check_returncode()
            lines = completed.stdout.splitlines()
            records = [line.removeprefix("RNG_RESULT ") for line in lines if line.startswith("RNG_RESULT ")]
            assert len(records) == 1, completed.stdout + completed.stderr
            observed_mode, seconds, milliseconds, values = records[0].split()
            assert observed_mode == mode
            sequence = [int(value) for value in values.split(",")]
            assert len(sequence) == 12
            sample = {"mode": mode, "launch": launch, "seconds": int(seconds), "milliseconds": int(milliseconds), "sequence": sequence}
            result["samples"].append(sample)
            result["lua"] = next(line.removeprefix("RNG_LUA ") for line in lines if line.startswith("RNG_LUA "))
            print(json.dumps(sample), flush=True)
    result["distinct_sequences"] = {
        mode: len({tuple(sample["sequence"]) for sample in result["samples"] if sample["mode"] == mode})
        for mode in ("omitted", "explicit", "fixed")
    }
    assert result["distinct_sequences"]["fixed"] == 1, "Fixed seed control did not reproduce"
    (output / "results.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result["distinct_sequences"]))


if __name__ == "__main__":
    main()
