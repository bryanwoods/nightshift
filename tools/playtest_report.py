#!/usr/bin/env python3
"""Summarize a playtest log written by Game.playtest().

Usage: python3 tools/playtest_report.py [path/to/session.log]
With no path, it reads the newest log in the game's user folder.
"""
import json
import sys
from pathlib import Path

USER_DIRS = [
    Path.home() / "Library/Application Support/Godot/app_userdata/Nightshift/playtest",
    Path.home() / ".local/share/godot/app_userdata/Nightshift/playtest",
    Path.home() / "AppData/Roaming/Godot/app_userdata/Nightshift/playtest",
]
QUIET_SECONDS = 45


def newest_log():
    logs = [p for d in USER_DIRS if d.exists() for p in d.glob("*.log")]
    return max(logs, key=lambda p: p.stat().st_mtime) if logs else None


def mmss(seconds):
    return "%d:%02d" % (seconds // 60, seconds % 60)


def main():
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else newest_log()
    if not path or not path.exists():
        sys.exit("No playtest log found.")
    events = []
    for line in path.read_text().splitlines():
        t, clock, room, event, fields = line.split("\t", 4)
        events.append((float(t), clock, room, event, json.loads(fields)))
    if not events:
        sys.exit("The log is empty.")

    print(f"Log: {path}")
    print(f"Real time played: {mmss(events[-1][0])}")

    print("\nRooms (real time spent, clock on entry):")
    rooms = [e for e in events if e[3] == "room"]
    for i, (t, clock, room, _, _) in enumerate(rooms):
        end = rooms[i + 1][0] if i + 1 < len(rooms) else events[-1][0]
        print(f"  {clock}  {room:<16} {mmss(end - t)}")

    curfew = next((e for e in events if e[3] == "battle_start" and e[4].get("worker") == "curfew"), None)
    print(f"\nReached Curfew at: {curfew[1] if curfew else 'did not reach Curfew'}  (target 2:36 to 2:44)")

    print("\nFights:")
    for t, clock, room, event, f in events:
        if event == "battle_end":
            print(f"  {f['worker']}: {f['result']} in {f['turns']} turns, {f['minutes']} min on the clock, "
                  f"{f['seconds']} s real. Hits {f['hits']} ({f['damage']} damage, {f['awake_left']} Awake left), "
                  f"blocked {f['blocked']}, rewinds {f['rewinds']}.")
            print(f"    actions: {', '.join(f['actions'])}")
            if f.get("hustle"):
                print(f"    hustle presses (5 = center, 2 = edge, 0 = miss): {f['hustle']}")
    hits = {}
    for t, clock, room, event, f in events:
        if event == "battle_hit":
            key = f"{f['worker']} {f['pattern']}"
            hits[key] = hits.get(key, 0) + 1
    if hits:
        print("  hits by pattern: " + ", ".join(f"{k} {v}" for k, v in sorted(hits.items(), key=lambda x: -x[1])))

    print("\nChoices:")
    for t, clock, room, event, f in events:
        if event == "choice":
            print(f"  {clock}  {room:<16} {f.get('prompt', '')[:40] + ' -> ' if f.get('prompt') else ''}{f['text']}")

    lamps = [e for e in events if e[3] == "hold_done"]
    print(f"\nLamps lit: {len(lamps)}")

    print(f"\nQuiet stretches over {QUIET_SECONDS} s (maybe stuck or lost):")
    quiet = [(events[i - 1], events[i]) for i in range(1, len(events)) if events[i][0] - events[i - 1][0] > QUIET_SECONDS]
    for a, b in quiet:
        print(f"  {mmss(a[0])} to {mmss(b[0])} in {a[2]}, after {a[3]} {json.dumps(a[4])[:60]}")
    if not quiet:
        print("  none")

    for t, clock, room, event, f in events:
        if event == "night_end":
            print(f"\nNight ended: {f['reason']} at {clock}")


if __name__ == "__main__":
    main()
