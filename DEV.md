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
Confirm at a lit lamp saves. See "Saving" below.

## Debug keys (debug builds only)

| Key | Does |
|---|---|
| F1 | Add 10 minutes (starts the clock if it reads 1:59) |
| F2 | Give the watch (`has_watch`) |
| F3 | Start the Curfew fight in the current room |
| F4 | Toggle every flag listed in `dev/flags.txt` |
| F5 | Reload the current room and all dialogue from JSON |
| F6 | Save now (commit live state to disk) |
| F7 | Next room in `data/rooms`, at its default spawn, with every story flag cleared |
| F8 | Save the screen as `screens/<room>.png` and `screens/<room>_4x.png` |
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
| `gallery.tscn` | Every sprite, tile and portrait at 4x, labeled with its text file; saves `screens/gallery_<page>.png` | |
| `autotest.tscn` | A bot plays Night 1 and checks clock, flags, rooms | `route=help\|hustle\|clock\|asleep\|night2\|input\|rewind\|forget\|finish\|encounters\|alley\|tour`, `shots=/some/dir` |

Routes: `help` and `hustle` play the whole night each way. `finish` checks a finished worker
across a save: his post is empty, the bread is on the steps, Wick and the Foreman notice,
and the hours carry. `tour` (with `shots=DIR` and a window) takes screenshots of every
room, every Curfew pattern, Pockets, the spare-or-finish choice and a finish. `clock` runs out the time on
Maple Street. `asleep` falls asleep in the Un-Baker fight. `night2` plays Night 1, presses
Continue and plays Night 2. `input` uses real key presses for walls, interact, doors,
hold-to-light, the battle menu, Hustle timing, and 3:00 in the middle of a fight. `rewind`
presses the watch in the Curfew fight. `alley` checks the secret alley. `encounters` spares the Un-Baker, helps the Window Washer, finishes the Puddle Keeper, saves,
and checks all three the next night. `forget` checks the save model: an unsaved friend is
forgotten at the end of the night, and a friend saved at a lamp is kept.

The bot prints `AUTOTEST PASS` or `AUTOTEST FAIL` and quits. It runs headless:

```sh
Godot --headless --path . res://dev/autotest.tscn -- route=help
```

Without `--headless` and with `shots=DIR` it saves screenshots along the way.

## Screenshots for review

One command makes the whole gallery:

```sh
Godot --path . -- --screens
```

It shows every room at its default spawn with no story flags, saves each one as
`screens/<room>.png` (1x) and `screens/<room>_4x.png`, then saves the sprite gallery
(`screens/gallery_*.png`) and quits. Godot draws nothing without a window, so a small
window opens for about twenty seconds. `screens/` is not in git.

## Where things live

```
src/autoload/   Game, NightClock, SaveManager, AudioBus, DialogueRunner
src/overworld/  world (room + battle holder), room (loader), entity, follower, player
src/dialogue/   textbox
src/battle/     battle, arena, patterns/ (one script per pattern type)
src/ui/         title, settings, credits, clock HUD, lamps screen, night end, Help Wanted board, menu list
src/validator.gd  checks every data file at startup
data/           everything the player reads, and every number worth tuning
assets/px/      every sprite, tile and portrait as text; tools/compile_px.py builds the PNGs
tools/gen_audio.py  makes the placeholder sounds and music
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
(a name or a list) that decide if the entity exists right now. `if_gone` / `unless_gone`
take worker ids instead of flags. Tile overrides take the same four fields.

| type | Fields | Does |
|---|---|---|
| `npc` | `id`, `sprite`, `dialogue`, `facing`, `idle_frames` | Stands there. Talk with Confirm |
| `inspect` | `dialogue`, `w`, `h` | Something to look at |
| `door` | `to`, `spawn`, `minutes`, `dialogue`, `w`, `h` | Walk into it. Costs the door minutes (default from tuning) |
| `trigger` | `dialogue`, `once`, `flag`, `w`, `h` | Walk into it. `once` + `flag` sets the flag and never fires again |
| `hold` | `dialogue`, `seconds`, `minutes`, `light`, `flag`, `hint` | Hold Confirm to fill a bar. Ticks the clock as it fills, then lights `light`, sets `flag`, runs `dialogue` |
| `encounter` | `worker`, `approach`, `respawn`, `radius`, `facing`, `light`, `approach_enemy`, `chat`, `after` | A worker at a post. Come close or press Confirm: the approach line, then the fight. See "An encounter" below |
| `false_wall` | `tile`, `to`, `spawn`, `minutes` | Looks like the wall under it and is solid. Inside the flashlight beam it shows `tile` (a gap) and is walkable; walking in goes to `to`, like a door |
| `lamp` | `id`, `light`, `wick` | A save point. The flag `lamp_<id>` means lit, and `light` is on while it is. Dark: Wick lights it (2 min), or it lights itself when `wick` is `false`. Lit: Confirm offers a save |

### Dialogue

`data/dialogue/<file>.json`. A file holds one dialogue (`lines`) or many (`dialogues`
keyed by id). Every id is global, so any file can `goto` any dialogue.

A dialogue can carry a `todo` field. The game never shows it; search for `TODO(Tadzio)`.

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
| `save` | | Commit live state to disk, as a lamp save does |

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
     "hours": 8,
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
                   "satisfied": "postman_satisfied", "spared": "postman_spared" },
     "rewards": { "satisfied": { "item": "blank_envelope" } }
   }
   ```

2. Add those seven dialogue ids to any file in `data/dialogue/`, and the item to
   `data/items.json`. An item with `awake` (Awake back) or `block` (`true`: blocks the next
   hit this round) shows in Pockets; give it a `use_text` and a short `effect` (one line in
   Pockets, under the selected item).
3. Draw the battle sheet `assets/px/sprites/postman_battle.txt`: two frames, `@idle_0` and
   `@idle_1`, 32x64 to 48x96. The validator reports a worker with no battle sheet, and a
   `job` of more than 6 words.
4. Start the fight from a dialogue with `{ "cmd": "battle", "worker": "postman" }`.
5. Try it alone: `Godot --path . res://dev/test_battle.tscn -- worker=postman wick`.

The outcome flags are fixed: `friend_<id>`, `enemy_<id>`, `gone_<id>`. `rewards` can give an
`item` for `satisfied`, `spared` or `finished`.

Optional worker fields: `arena` `[w, h]`, `idle_frames`, `music`, `rewind_tutorial`,
`turn_lines` and `flavor` (lists of dialogue ids). Each turn, the arena shows the next
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

### An encounter

An encounter is a worker who stands at a post every night and fights when Tadzio comes
close. Say the Night Postman from the example above should stand on Main Street.

1. Make the worker file and its dialogue, as in "A worker". Give the worker an `approach`
   line too: what happens when Tadzio walks up.
2. Add one entity to `data/rooms/street_main.json`, in `entities`:

   ```json
   { "type": "encounter", "worker": "postman", "x": 13, "y": 7, "facing": "left",
     "respawn": "nightly", "approach": "postman_approach" }
   ```

   `x` and `y` are where the worker's feet are, in tiles. The fight starts when Tadzio is
   within `radius` tiles (default 2) or presses Confirm at the worker.
3. Optional fields:

   | Field | Meaning |
   |---|---|
   | `approach_enemy` | The approach line for the night after Tadzio let them go |
   | `chat` | What a friend says when Tadzio presses Confirm. Friends do not fight again |
   | `after` | `{ "satisfied": id, "spared": id, "finished": id }`: a line after the fight |
   | `light` | The id of a light in this room. It is on while the worker is at the post |
   | `respawn` | `never` for a secret boss: once the fight is over, any way, they never come back |

4. Show the job nobody does when the worker is gone. Any entity or tile override can take
   `if_gone` or `unless_gone` with the worker's id:

   ```json
   { "type": "inspect", "x": 12, "y": 7, "dialogue": "postbox_full", "if_gone": "postman" }
   ```

5. Add a line for the Foreman in `foreman_missing` (`data/dialogue/depot.json`) with
   `"if_flag": "gone_postman"`.
6. Walk up to the worker, or try the fight alone with
   `Godot --path . res://dev/test_battle.tscn -- worker=postman wick`.

The Window Washer (`data/workers/window_washer.json`, `data/dialogue/window_washer.json`)
and the Puddle Keeper are complete small examples.

### A secret room

A secret room is a normal room behind a `false_wall`. Say there should be a hidden yard
behind the Depot.

1. Make `data/rooms/depot_yard.json` like any room. Give it a spawn near its way out, for
   example `"spawns": { "default": [3, 5, "up"], "secret": [3, 5, "up"] }`, and a door back:
   `{ "type": "door", "x": 3, "y": 6, "to": "depot_exterior", "spawn": "yard" }`.
2. In `data/rooms/depot_exterior.json`, pick a wall tile and put a false wall on it:

   ```json
   { "type": "false_wall", "x": 13, "y": 1, "tile": "alley_gap", "to": "depot_yard", "spawn": "secret" }
   ```

   Also add the spawn `"yard"` just below that tile, facing down.
3. That is all. In the dark the tile is the wall it was. Inside the flashlight beam it shows
   `alley_gap` and Tadzio can walk through. Do not add a label or an inspect spot there.
4. Optional: a lamp with `"wick": false` (it lights itself), and a boss as an `encounter`
   with `"respawn": "never"`. A worker file can hide its name and job in the fight with
   `"name_tag": false`.

`data/rooms/alley_1.json` and `data/workers/no_job.json` are the example. The `alley` route
of the autotest bot checks it: the wall stays solid with the flashlight off, opens with it
on, and the key and the quiet alley last into the next night.

### A Help Wanted posting

Add `{ "title", "posted_by", "text", "status" }` to `data/help_wanted.json`.
`status` is `open`, `taken` or `done`.

## Saving

The town forgets every night. Only what was saved at a lamp stays. `SaveManager` keeps two
copies: live state (`Game.flags`, `items`, `hours`, `tally`, `seen`) and committed state
(`user://save.json`). `commit()` writes live to disk. At the end of the night, `revert()`
puts live back to the last commit, and `lamps_screen` lists what was kept and what was
forgotten. Flags that start with `tonight_` never save. `data/items.json` holds item names.

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

`data/tuning.json` holds the minute costs, Awake, Shift Level thresholds, token speed, rewind frames and
charges, Hustle timing, text speed, music tension and the arena size.
`show_choice_rewards` shows the hours on "Let them go" and "Clock them out" (`TODO(Tadzio)`:
keep them or hide them). Door minutes can
also be set per door (`minutes`). Street-to-street doors cost 3.

## Art and sound

All art is text in `assets/px/`. `tools/compile_px.py` turns it into the PNGs in
`assets/sprites`, `assets/tiles` and `assets/portraits`. Never edit those PNGs: the next
compile writes over them. The compiler also checks the warm rule: each npc, encounter, door, lamp
and inspect spot in `data/rooms/` must show two touching `lamp` or `moon` pixels, or nothing
is written. A door wider than one tile is an edge exit, and a false wall is a secret, so they
are skipped. The three soft light shapes (`light_radial`, `light_cone`,
`glow`) are made in code in the same script, because a letter cannot draw a soft edge.

```sh
uv run --with pillow python tools/compile_px.py        # build every PNG
uv run --with pillow python tools/test_compile_px.py   # check the compiler itself
python3 tools/gen_audio.py                             # sounds and music
```

Where each file goes:

| Text file | PNG |
|---|---|
| `assets/px/sprites/<name>.txt` | `assets/sprites/<name>.png`, frames 4 across in file order. Characters: rows down, up, left, right; 4 walk frames each, frame 0 stands still |
| `assets/px/portraits/<name>.txt` | `assets/portraits/<name>_<frame>.png`, one PNG for each frame (`@neutral`, `@happy`) |
| `assets/px/tiles/<tileset>/<tile>.txt` | one square of `assets/tiles/<tileset>.png`, in the order of `data/tilesets.json`. A file in `assets/px/tiles/` without a tileset folder is shared by every tileset that does not have its own |

`tools/legacy/gen_placeholders.py` is the old generator. Do not run it. Delete it after
2026-11-11.

### Draw a sprite in a text editor

You can change any picture in the game with a text editor. Every letter is one pixel.

1. Open the folder `assets/px`. Characters and small things are in `sprites`. Faces are in
   `portraits`. The squares of floors and walls are in `tiles`.
2. Open a file, for example `assets/px/sprites/wick.txt`.
3. Use a font where every letter has the same width. Most code editors already do. Then
   the rows line up and you can see the picture.
4. The first line tells the name and the size. `# wick 16x32` means 16 letters across
   and 32 rows down.
5. A line that starts with `@` starts one picture. We call it a frame. Wick has 16 frames:
   4 for walking down, 4 for up, 4 for left, and 4 for right.
6. Some frames are copies. `@down_2 = down_0` means "the same as down_0".
   `@right_0 = flip left_0` means "the same as left_0, but mirrored". Change the first
   one, and the copies change too.
7. Change some letters. Every row in a frame must have the same number of letters.
8. Save the file. In a terminal, in the nightshift folder, type:
   `uv run --with pillow python tools/compile_px.py`
9. If something is wrong, it tells you the file and the line, for example:
   `assets/px/sprites/wick.txt:12: row is 15 wide, it needs 16`.
   Go to line 12, fix it, and type the command again. Nothing changes until all the
   mistakes are gone.
10. Open the game. Godot finds the new picture by itself.

The letters:

| Letter | Color | Looks like |
|---|---|---|
| `.` | clear | see-through |
| `k` | ink | almost black, for outlines |
| `n` | night | very dark blue |
| `d` | dusk | dark blue |
| `s` | slate | grey blue |
| `f` | fog | light grey blue |
| `m` | moon | cream white |
| `l` | lamp | warm orange yellow |
| `e` | ember | bright orange |
| `h` | hush | pink red |
| `w` | wake | mint green |
| `y` | straw | blond |
| `o` | honey | golden brown |
| `c` | cream | morning cream |
| `b` | butter | morning yellow |
| `a` | sky | morning blue |
| `g` | leaf | morning green |
| `r` | bark | morning brown |
| `t` | white | white |

The colors are in `data/palette.json`. A new color needs a new letter there. The rules
for how things should look are in SPEC.md, under Art.

To make a new picture, copy a file that is the same size, give it a new name, and change
the name on the first line too.

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
- Before a dark turn, the battle menu cursor moves to Wick and the warning says "Ask Wick!". In the first playtest, the player chose Hustle on the dark turn and lost 15 of 20 Awake.
- The crate beside the Depot side door opens the lost-and-found. In the first playtest, the player inspected that crate and missed the bin one tile away, so they never got the watch.
- Round 2: the backyard has no lamp. It is part of the house, Wick is not there yet, and the night has not started, so there is nothing to save.
- Round 2: the save prompt opens right after a lamp lights, so the first lamp teaches saving. Lighting costs 2 minutes; saving is free.
- Round 2: the optional hold lamps (+2 min each) stay. They light for one night and do not save.
- Round 2: seen dialogue reverts with the rest, so an unsaved first meeting plays again.
- Round 2: Continue shows after the first lamp save or the first finished night. There is no autosave.
- Round 2: a spared worker gives 1 hour, but never more than their `hours`, so the practice dummy (0 hours) gives nothing.
- Round 2: sparing someone who was a friend clears the friendship; helping someone who was an enemy clears the grudge.
- Round 2: Wick's first line about a finished worker plays inside the fight, so it works for every fight, also Curfew's.
- Art review 2: the battle screen has three columns. The worker's name, job and battle sheet are on the left, the 120x80 arena is in the middle, and the task, Patience, Shift Lv and Awake are on the right. The textbox, the hint and the speech bubble share the strip below the arena, right of the worker, so none of them covers the arena, a meter or the worker. Pockets lists items inside the arena. Battle prompts sit inside the top of the arena.
- Art review 2: a lamp post is a 16x32 sprite (`assets/px/sprites/lamp_post.txt`) over its `lamp_post` tile, which holds only the sidewalk and the collision. The sprite shows `@lit` while the light on its tile is on.
- Round 2: if Curfew is gone, the square has no fight and the night ends at 3:00.
- Round 2: friends do not fight again. They stand at their post and chat. Their item comes once, when they are first helped.
- Round 2: the practice dummy stands in the backyard, so practice comes before 2:00 and costs no minutes.
- Round 2: the Un-Baker stands at his post from the start of the night, with his cart and a lantern. He no longer walks in.
- Round 2: the flashlight starts off every night, and the bedroom names its key once. Without this, the check "a player who never turns it on never finds the alley" could not hold.
- Round 2: a false wall stays open while Tadzio stands in it, so the gap cannot close on him.
- Round 2: the key to nothing comes from every outcome of the alley fight ("a strange reward either way").
- Round 3: `--screens` opens a window. Godot's headless mode has no renderer, so it cannot take a screenshot.
- Round 3: the screenshot loop came before the art (Item 4 before Item 3), because each art group ends with a new gallery.
- Commits are not one per milestone: the slice was built in one pass, then tested by the autotest bot.

## Open questions for Bryan

See `NOTES_FOR_BRYAN.md`.
