# Nightshift — developer notes

Night 1 vertical slice. Godot 4.7 (GDScript), Compatibility renderer, 320×180 integer-scaled.

## Run it

1. Install Godot 4.4 or newer (`brew install --cask godot` on macOS).
2. Open `project.godot` in Godot and press F5. Or from a shell:

   ```sh
   /Applications/Godot.app/Contents/MacOS/Godot --path .
   ```

3. Choose **New Night**.

The first open imports the assets into `.godot/`. That folder is not in git.

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | Arrows, WASD | Left stick, D-pad |
| Confirm / talk / inspect | Z, Space, Enter | A |
| Cancel / skip text | X, Esc | B |
| Rewind (in a fight, once you own the watch) | R, Shift | Left bumper |
| Flashlight on/off | C, Tab | Y |
| Fullscreen | F11 | |

Hold Confirm near a hold spot (a dark lamp after Wick joins) to fill the bar.

## Debug keys (debug builds only)

| Key | Does |
|---|---|
| F1 | Add 10 minutes (starts the clock if it reads 1:59) |
| F2 | Give the watch (`has_watch`) |
| F3 | Start the Curfew fight in the current room |
| F4 | Toggle every flag listed in `dev/flags.txt` |
| F5 | Reload the current room and all dialogue from JSON |
| F11 | Fullscreen |

Data errors show in red at the top of the screen and in the Godot output, as
`file: field: problem`. Fix the file, then press F5.

## Dev scenes

Run one with `Godot --path . res://dev/<scene>.tscn -- <args>`.

| Scene | What it tests | Args |
|---|---|---|
| `test_room.tscn` | One room, clock running | `room=street_maple` |
| `test_dialogue.tscn` | One dialogue on a blank screen; shows flags after | `dialogue=wick_intro` |
| `test_battle.tscn` | One fight with no room | `worker=unbaker`, `wick`, `watch` |
| `autotest.tscn` | A bot plays Night 1 and checks clock, flags, rooms | `route=help\|hustle\|clock\|asleep\|night2\|input\|rewind`, `shots=/some/dir` |

Routes: `help` and `hustle` play the whole night each way. `clock` runs out the time on
Maple Street. `asleep` falls asleep in the Un-Baker fight. `night2` plays Night 1, presses
Continue and plays Night 2. `input` uses real key presses for walls, interact, doors,
hold-to-light, the battle menu, Hustle timing, and 3:00 in the middle of a fight. `rewind`
presses the watch in the Curfew fight.

The bot prints `AUTOTEST PASS` or `AUTOTEST FAIL` and quits. It runs headless:

```sh
Godot --headless --path . res://dev/autotest.tscn -- route=help
```

Without `--headless` and with `shots=DIR` it saves screenshots along the way.

## Where things live

```
src/autoload/   Game, NightClock, SaveManager, AudioBus, DialogueRunner
src/overworld/  world (room + battle holder), room (loader), entity, follower, player
src/dialogue/   textbox
src/battle/     battle, arena, patterns/ (one script per pattern type)
src/ui/         title, settings, credits, clock HUD, night end, Help Wanted board, menu list
src/validator.gd  checks every data file at startup
data/           everything the player reads, and every number worth tuning
tools/gen_placeholders.py  makes all placeholder art and sound from data/palette.json
```

## Adding content

Every JSON file has an `id` that matches its file name. IDs are snake_case.

### A room

`data/rooms/<id>.json`. Draw the room as text in `layout`. Each character maps to a
tile name in `legend`; the tile names come from `data/tilesets.json`.

| Field | Meaning |
|---|---|
| `tileset` | `home_night`, `home_morning`, `town_night` or `depot_night` |
| `spawns` | name → `[x, y]` or `[x, y, "up"]`. Needs `default` |
| `entities` | see below |
| `lights` | `{id, x, y, radius, on, color?, energy?}`; `color` is a palette name |
| `ambient` | darkness, 0 (black) to 1 (full light) |
| `music` | a file name in `assets/music/` without the extension, or `none` |
| `on_enter` | a dialogue id that runs every time you enter (guard it with a flag) |
| `companion` | `true` if Wick follows you here once he has joined |
| `overrides` | `{x, y, tile, if_flag}`: swap one tile when a flag is set |
| `hud`, `flashlight`, `background` | `false`, `false`, a palette name |

Entity types. All take `x`, `y` in tiles, and optional `if_flag` / `unless_flag`
(a name or a list) that decide if the entity exists right now.

| type | Fields | Does |
|---|---|---|
| `npc` | `id`, `sprite`, `dialogue`, `facing`, `idle_frames` | Stands there. Talk with Confirm |
| `inspect` | `dialogue`, `w`, `h` | Something to look at |
| `door` | `to`, `spawn`, `minutes`, `dialogue`, `w`, `h` | Walk into it. Costs the door minutes (default from tuning) |
| `trigger` | `dialogue`, `once`, `flag`, `w`, `h` | Walk into it. `once` + `flag` sets the flag and never fires again |
| `hold` | `dialogue`, `seconds`, `minutes`, `light`, `flag`, `hint` | Hold Confirm to fill a bar. Ticks the clock as it fills, then lights `light`, sets `flag`, runs `dialogue` |

### Dialogue

`data/dialogue/<file>.json`. A file holds one dialogue (`lines`) or many (`dialogues`
keyed by id). Every id is global, so any file can `goto` any dialogue.

A line has `speaker` (from `_speakers.json`), `portrait` (a file in
`assets/portraits/` without `.png`; defaults to `<speaker>_neutral`), `text`, optional
`choices`, optional `auto` (seconds, then it moves on by itself), and optional
`if_flag` / `unless_flag` to skip the line. `{confirm}`, `{rewind}`, `{cost_help}` and
friends are replaced with the real key or number.

A dialogue can have `seen_variant`: once it has been seen (this night or any night
before), that dialogue plays instead. Variants can chain.

Choices: `{ "text": "...", "goto": "other_id", "if_flag": "..." }`. A choice's goto
runs that dialogue and then **comes back**. A choice with no goto just continues.

Commands (`{ "cmd": "..." }`):

| cmd | Fields | Does |
|---|---|---|
| `set_flag` / `clear_flag` | `flag` | |
| `if_flag` | `flag`, `goto`, `else` | **Jumps**: runs goto (or else) and stops here. No else and no flag: carries on. `goto: ""` just stops |
| `goto` | `goto` | Jumps |
| `clock_add` | `minutes` | |
| `clock_set` | `minute` | 0 = 2:00, 60 = 3:00 (ends the night) |
| `battle` | `worker` | Fight; the dialogue goes on after the fight |
| `give_item` | `item` | |
| `light` | `id`, `on` | Lasts for this night |
| `move` | `entity`, `dx`, `dy`, `speed` | Walk in tiles. `entity` can be `player` or `wick` |
| `face` | `entity`, `dir` | |
| `shake` | `strength`, `seconds` | |
| `wait` | `seconds` | |
| `music` | `track` | |
| `sfx` | `name`, `pitch` | |
| `end_night` | | At night: it is 3:00 now. In the morning: show the Night End card |
| `help_wanted` | | Open the Help Wanted board |

### A worker (worked example)

Say Tadzio wants a **Night Postman** fight. Four steps, no code:

1. Make `data/workers/postman.json`:

   ```json
   {
     "id": "postman",
     "name": "The Night Postman",
     "job": "Delivers dreams in envelopes",
     "sprite": "postman", "portrait": "postman", "size": "normal",
     "patience": 12,
     "hit_damage": 2,
     "patterns": [
       { "type": "drift", "duration": 6, "count": 5, "speed": 35, "turn_rate": 1.0, "sprite": "note" },
       { "type": "rain", "duration": 6, "count": 8, "speed": 55, "sprite": "crumb" }
     ],
     "task": {
       "title": "Sort the dreams",
       "steps": [
         { "label": "Hold the bag", "line": "postman_help_1" },
         { "label": "Find the right house", "line": "postman_help_2",
           "choice": { "prompt": "The envelope says...", "options": ["No. 4", "No. 9"], "correct": 0,
                       "wrong_line": "postman_help_2_wrong" } }
       ]
     },
     "dialogue": { "intro": "postman_battle_intro", "hustle_hit": "postman_hustle",
                   "satisfied": "postman_satisfied", "defeated": "postman_defeated" },
     "rewards": { "satisfied": { "flag": "friend_postman", "item": "blank_envelope" },
                  "defeated": { "flag": "enemy_postman" } }
   }
   ```

2. Add those seven dialogue ids to any file in `data/dialogue/`.
3. Start the fight from a dialogue with `{ "cmd": "battle", "worker": "postman" }`.
4. Try it alone: `Godot --path . res://dev/test_battle.tscn -- worker=postman wick`.

Optional worker fields: `arena` `[w, h]`, `idle_frames`, `music`, `rewind_tutorial`,
`turn_lines` and `flavor` (lists of dialogue ids). Each turn, the menu panel shows the next
`flavor` line, and the dodge phase opens with the next `turn_lines` line in a speech bubble
beside the worker. The bubble never waits for a key. A task step can also have a `bubble`
(a dialogue id); it replaces the turn line after that step. A Hustle hit uses `hustle_hit`
as the bubble. Keep step lines to one or two short lines: the fight should keep moving.
A pattern can also take `arena`, `damage` and `duration`.

Pattern types and their params:

| type | params |
|---|---|
| `rain` | `count`, `speed`, `sprite`; `lanes` + `sequence` drop them in a lane order with a note per lane |
| `sweep` | `bars`, `gap_px`, `speed`, `from` (`left`, `right`, `both`) |
| `ring` | `rings`, `speed`, `gap_angle` |
| `drift` | `count`, `speed`, `turn_rate`, `sprite` |
| `dark` | `inner`: another pattern. Invisible unless Wick used Light |

A new pattern type is one new script in `src/battle/patterns/`, named after the type.

### A Help Wanted posting

Add `{ "title", "posted_by", "text", "status" }` to `data/help_wanted.json`.
`status` is `open`, `taken` or `done`.

## Playtest log

Every session writes one log, `playtest/<date-time>.log`, in the game's user folder
(macOS: `~/Library/Application Support/Godot/app_userdata/Nightshift/`). It records rooms,
dialogues, choices, lamps, fights, hits, rewinds and the end of the night, each with
real seconds and the in-game clock. It is flushed line by line, so quitting keeps it.
The autotest bot deletes its own logs.

```sh
python3 tools/playtest_report.py            # the newest log
python3 tools/playtest_report.py some.log   # one log
```

The report gives real time per room, the clock when Curfew starts (target 2:36 to 2:44),
each fight's turns, hits by pattern, Hustle presses, the choices made, and quiet stretches
over 45 seconds, which can mean the player was stuck.

## Export

Export templates for the Godot version must be installed (Editor, Manage Export Templates).

```sh
Godot --headless --path . --export-release "macOS" build/macos/Nightshift.app
Godot --headless --path . --export-release "Windows Desktop" build/windows/Nightshift.exe
```

Release builds have no debug keys and no on-screen data errors. `dev/` is left out.

## Tuning

`data/tuning.json` holds the minute costs, Awake, token speed, rewind frames and
charges, Hustle timing, text speed, music tension and the arena size. Door minutes can
also be set per door (`minutes`). Street-to-street doors cost 3.

## Art and sound

`uv run --with pillow python tools/gen_placeholders.py` rewrites every placeholder.
Replace any file with real art of the same size and layout; no code changes.
Character sheets: 4 columns (walk frames, frame 0 = idle) × 4 rows (down, up, left,
right). 16×32, 32×32 or 48×48 frames. Portraits 32×32, `<speaker>_<mood>.png`.
After you add a new image, open the project in Godot once so it imports it.

## Decisions

Choices the spec left open, and choices that bend it. Each is one line so it is easy to undo.

- Input actions are registered in code (`Game._register_inputs`), not in `project.godot`. Easier to read and diff.
- Font: m6x11 by Daniel Linssen at size 16, the spec's second pick. Its itch.io page says "free to use with attribution" (`assets/fonts/m6x11-LICENSE.txt`). It has no em dash or curly quotes, so dialogue uses `-` and straight quotes, and the validator reports any character the font cannot draw.
- One `Entity` script covers npc, inspect, door, trigger and hold, and `room.gd` is also the room loader. Fewer files than the spec's list; same behavior.
- Dialogue files can bundle many dialogues (`dialogues: {}`), so one file per room instead of one per line.
- Choice goto comes back (a call). `goto` and `if_flag` commands jump. Matches the spec example, where `set_flag met_wick` comes after the choice.
- Flags that start with `tonight_` reset every night. Everything else carries over. Lamps lit with the `light` command also reset.
- The HUD clock shows 1:59 dimmed indoors and turns bright at 2:00, so it both "reads 1:59 indoors" and "appears" at the gate.
- Settings are in `user://settings.json`, not `save.json`, so changing the volume does not make Continue appear.
- Hold spots are a new entity type (`hold`). The lamp tutorial is the first one. After Wick joins, some dark lamps are optional hold spots (+2 min each). This is how a thorough player reaches Curfew near 2:40.
- Street-to-street doors cost 3 minutes. Indoor doors cost 1.
- Battle pacing follows Deltarune's rhythm: one short line, then the dodge. Worker quips are speech bubbles that do not wait for a key. Dodge phases are 4.5 to 5 seconds (spec: 6 to 7) with faster projectiles. The menu box widens to a text panel between dodges.
- The Un-Baker fight has its own `battle_loop` music. Curfew keeps the lullaby.
- A help action that finishes the task ends the fight at once. There is no dodge phase or round tick after it.
- Hustle with no press in the sweep does 0 damage.
- Rings start the token near the bottom of the arena, because a ring grows from the center.
- The "glow shader" on the token is a generated glow texture, not a shader.
- Music loops are about 30 to 50 seconds (spec: 60 to 90). They are generated placeholders.
- Tiles change by flag through `overrides` (the Depot side door opens).
- The punch card is always on the nightstand in the morning, also after falling asleep.
- `end_night` in the morning opens the Night End card; at night it rings 3:00.
- The palette has two extra night colors, `straw` and `honey`, for Tadzio's dirty-blonde hair. With only the spec's ten colors, the hair read as ginger.
- Tadzio's sprite and portraits are drawn from a photo: long straight hair parted in the middle, light eyes, a small closed smile. The pajamas copy his white-and-teal colorblock shirt. The pajama pattern is still `TODO(Tadzio)`.
- Wick counts as a friend (`friend_wick`) once he joins, so the Night End card lists him.
- Commits are not one per milestone: the slice was built in one pass, then tested by the autotest bot.

## Open questions for Bryan

See `NOTES_FOR_BRYAN.md`.
