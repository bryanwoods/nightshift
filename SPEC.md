# Nightshift spec

Part 1 is the original vertical slice spec (v0.1), as written. The sections after it were
added in later rounds. Where a later section and v0.1 do not agree, the later section is
correct.

---

Nightshift — Vertical Slice Spec v0.1
Oct 31, 2026 · @Bryan
Overview
Build a playable 15-minute vertical slice of Nightshift, an original top-down RPG in the spirit of Undertale and Deltarune, in Godot 4 (GDScript), in one week. The slice is one complete in-game night, start to finish, with a working overworld, dialogue system, and battle system driven entirely by JSON data files.
The slice has two audiences. The first player is Tadzio, who is the game’s co-designer from the first play; the second is Claude Code, which will build it from this spec. Every content type (rooms, dialogue, enemies, job postings) must be addable by editing a data file, with no engine changes.
Targets
Item
Decision
Engine
Godot 4.4 or newer stable, GDScript, static typing
Platforms
Windows and macOS desktop exports; Linux if free. Steam later
Internal resolution
320×180, integer-scaled, pixel-perfect
Input
Keyboard first, gamepad supported from day 1
Session length
12–18 minutes for a first-time player
Rating target
Kid-safe. Nobody dies; losing a fight means falling asleep
Repo name
nightshift
Premise, tone and pillars
Every night from 2:00 to 3:00 the town has a second shift. The Nightshift puts the day back together: relights the lamps, returns lost things, winds the clocks, takes yesterday’s bread back. Nobody awake has ever seen them, until a kid named Tadzio wakes up at 1:59 and can.
The hour ends at 3:00 no matter what, and Tadzio wakes up in bed. What he learned, who he befriended, and what’s in his pockets carry over. The hour resets; the kid doesn’t.
The long game (not built in the slice, but everything should leave room for it): the hour is getting shorter. Someone is eating the minutes. If the hour disappears, the town stops resetting and mornings start going wrong. The town clock in the square is stopped at 2:00; that is the first clue, and the slice shows it without explaining it.
Tone: quiet, funny, a little eerie, never scary. Think a sleepy town at 2 AM where the fridge is humming a tune. Workers are tired, decent, overworked, and suspicious of a kid who shouldn’t be awake. Humor comes from mundane jobs done with total seriousness. Sincere moments land because the world is small and specific.
Design pillars
1. Minutes are the currency. A clock is always on screen. Moving between streets, every battle round, and every rewind spends minutes. Players trade night for outcomes.
2. Every worker is a job, and every job is a puzzle. You can hustle a worker (fight) or help them finish their task (the peaceful route). Helping is slower and makes a friend. Hustling is faster and makes an enemy.
3. One kid, one friend. Tadzio is alone in a sleeping town. Wick, an anxious moth lamplighter, is his only partner. Wick can’t fight, but he can light the arena and buy time.
4. Everything is a data file. Rooms, dialogue, workers, job postings. If Tadzio can describe it, it can be added in an afternoon.
5. The game knows it’s unfinished. The Help Wanted board in the Depot is a real in-game object that lists future content. Postings are written by the designers, including Tadzio.
What we borrow and what we don’t. Borrow: top-down pixel overworld, inspect-everything text, dodge-the-pattern battles with a non-violent resolution, characters who talk to the player. Don’t borrow: the heart soul, the white battle box, FIGHT/ACT/MERCY labels, black-and-neon palette, any character design or line from Toby Fox’s games. Original names, original mechanics, original look.
Tech stack and project structure
Godot 4 with GDScript, no third-party addons in the slice. Rooms are defined as ASCII maps in JSON and built into a TileMapLayer at runtime, so Claude Code can author levels as text and Tadzio can draw a room in a text editor. Tiled support can come later if hand-painting becomes worth it.
Project settings
Setting
Value
Viewport
320×180, stretch mode viewport, aspect keep, integer scaling on
Texture filter
Nearest (project default)
Physics
60 Hz; battle patterns step in _physics_process
Rendering
Compatibility renderer (widest hardware support)
Window
Opens at 1280×720 (4×); F11 toggles fullscreen
Folder layout
nightshift/
  project.godot
  DEV.md                      # how to run, debug keys, how to add content
  src/
    autoload/                 # Game, NightClock, SaveManager, DialogueRunner, AudioBus
    overworld/                # Player, Room, RoomLoader, NPC, Door, Trigger, Interactable
    dialogue/                 # Textbox scene, Portrait, ChoiceList
    battle/                   # Battle scene, Arena, Token, Menu, WorkerActor, Rewind
    battle/patterns/          # One GDScript per attack pattern
    ui/                       # ClockHUD, TitleScreen, NightEndScreen, HelpWantedBoard, Settings
  data/
    rooms/*.json
    dialogue/*.json
    workers/*.json
    help_wanted.json
    palette.json
    tuning.json               # minute costs, Awake values, pattern speeds
  assets/
    sprites/ tiles/ portraits/ fonts/ sfx/ music/
  tools/
    gen_placeholders.py       # generates placeholder sprites and tiles from palette.json
  dev/
    test_room.tscn test_dialogue.tscn test_battle.tscn
Autoloads (singletons)
Autoload
Owns
Key signals
Game
Current night number, flags dictionary, scene routing (room ↔ battle ↔ screens), debug keys
flag_set(name), scene_changed
NightClock
Current minute (0–60 after 2:00), paused state, cost table from tuning.json
minute_passed(minute), hour_ended
SaveManager
Load and save user://save.json, what carries across nights
saved, loaded
DialogueRunner
Loads data/dialogue/*.json, runs lines, choices, commands; owns the Textbox
dialogue_started(id), dialogue_ended(id)
AudioBus
Music loops with crossfade, SFX pool, per-speaker blip pitch
none
Input map
Action
Keyboard
Gamepad
move_* (4 directions)
Arrows, WASD
Left stick, D-pad
confirm / interact
Z, Space, Enter
A (bottom face)
cancel
X, Esc
B (right face)
rewind
R, Shift
Left bumper
menu
C, Tab
Y (top face)
fullscreen
F11
none
Data conventions. All text shown to the player lives in data/, never in scripts. IDs are snake_case. Every JSON file has an id matching its filename. Loaders validate on startup and print a clear error naming the file and field on failure, so a kid’s typo is a readable message, not a crash.
Core systems
Night clock
The clock is deterministic: minutes pass only on actions, never in real time, so levels can be designed to the minute. It reads 1:59 inside the house and starts at 2:00 when Tadzio steps through the backyard gate. The HUD shows it top-right at all times outside menus and title screens.
Event
Cost (minutes)
Room transition (door)
1
Inspecting objects, talking
0
Each battle round (after the dodge phase)
1
Help action, on top of the round
+2
Hustle, Stall
+0
Wick Light
0
Wick Hold
+1
Rewind (each use)
1
Scripted jump in a cutscene
any, via dialogue command
All costs live in data/tuning.json. At 60 minutes (3:00) hour_ended fires. Whatever is on screen stops, the screen fades to white over 1.5 s, and the Night End screen plays. If it fires mid-battle, the battle is abandoned with no winner and no flag set.
Overworld
Top-down, 4-direction movement at 60 px/s, grid-free with CharacterBody2D and 16×16 tile collision. Interact with confirm while facing an Interactable within 12 px. A small marker appears above anything interactable in range. Player sprite frames are 16×32; NPCs the same unless marked large (32×32 or bigger, e.g. Curfew).
Rooms load from data/rooms/<id>.json. RoomLoader builds a TileMapLayer from the ASCII layout and a legend, spawns entities, sets music and ambient darkness, then positions the player at the named spawn. Doors call Game.go_to_room(id, spawn) and charge the clock.
{
  "id": "street_maple",
  "tileset": "town_night",
  "legend": {
    "#": "wall", ".": "sidewalk", ",": "road", "~": "grass",
    "L": "lamp_post", "F": "fence", "D": "door_closed"
  },
  "layout": [
    "####################",
    "#~~~~F.........L...#",
    "#~~~~F.............#",
    "#....F,,,,,,,,,,,,,#",
    "#....F,,,,,,,,,,,,,.",
    "#L...F.............#",
    "####################"
  ],
  "spawns": { "default": [2, 5], "east": [18, 4] },
  "entities": [
    { "type": "npc", "id": "wick", "x": 6, "y": 5, "sprite": "wick", "dialogue": "wick_intro", "facing": "down" },
    { "type": "door", "x": 19, "y": 4, "to": "street_main", "spawn": "west" },
    { "type": "trigger", "x": 14, "y": 4, "once": true, "flag": "unbaker_seen", "dialogue": "unbaker_approach" },
    { "type": "inspect", "x": 15, "y": 1, "dialogue": "inspect_dark_lamp" }
  ],
  "lights": [ { "x": 15, "y": 1, "radius": 40, "on": false, "id": "lamp_maple_1" } ],
  "ambient": 0.3,
  "music": "street_loop"
}
Lights are PointLight2D nodes with the lamp-orange color; ambient is a CanvasModulate darkness level from 0 (black) to 1 (full). The player’s flashlight is a cone PointLight2D on the player, toggled with menu. Entities can carry "if_flag" / "unless_flag" so a room changes after story events.
Dialogue
A textbox at the bottom of the screen with a 32×32 portrait on the left, typewriter text at 30 characters/s (hold confirm to speed up, press again to finish), and a per-speaker blip sound every 2 characters. Tadzio speaks in short lines and through choices. Choices render as a vertical list inside the box.
{
  "id": "wick_intro",
  "lines": [
    { "speaker": "wick", "portrait": "wick_panic", "text": "A dayside kid. Awake. At— no. No no. What time is it?" },
    { "speaker": "tadzio", "text": "Two." },
    { "speaker": "wick", "portrait": "wick_sad", "text": "Fourteen lamps dark, the ladder’s busted, and the Foreman counts every one.",
      "choices": [
        { "text": "I can hold the light.", "goto": "wick_help" },
        { "text": "Who’s the Foreman?", "goto": "wick_foreman" }
      ] },
    { "cmd": "set_flag", "flag": "met_wick" }
  ]
}
Supported line fields: speaker, portrait, text, choices[] (each with text, goto, optional if_flag), and cmd. Commands: set_flag, clear_flag, if_flag (with goto and optional else), goto, clock_add (minutes), clock_set, battle (worker id), give_item, light (id, on/off), move (entity id, dx, dy), face, shake, wait (seconds), music, sfx, end_night. The runner pauses the overworld while active. Speaker names and blip pitches come from data/dialogue/_speakers.json.
Battle
A battle is a loop of menu phase → dodge phase → clock tick until the worker is resolved, Tadzio falls asleep, or 3:00 arrives. Transition in with a short 0.6 s wipe; the overworld is kept in memory and resumes after.
Layout. Worker sprite upper center, large portrait optional. Arena is a rounded rectangle lower center, 120×80 px default, resizable per pattern. Tadzio’s Awake meter (starts at 20) bottom-left, the worker’s Patience (their HP, from the data file) bottom-right, the clock top-right, rewind charges beside it once the watch is owned.
Token. The player controls the flashlight beam: a 6×6 px bright oval with a soft glow. 8-direction movement at 90 px/s. Getting hit costs Awake (2–4 per hit, per pattern) and gives 0.5 s of invulnerability. Awake 0 = Tadzio falls asleep on the spot, fade to white, wake in bed, night ends. Flags and items earned so far are kept.
Menu options (4 buttons across the bottom, labels are ours):
Option
What it does
Resolves the worker?
Help
Advances the worker’s task by one step. Each step shows a line and sometimes a 2–3 option sub-choice. Costs +2 minutes
When the last step is done: worker is satisfied, sets friend_<id>
Hustle
A timing bar: press confirm in the center zone for 5 damage, edges for 2. Reduces Patience
At Patience 0: worker storms off, sets enemy_<id>
Stall
Skip your turn; incoming damage this round halved
No
Wick
Wick takes his own turn after Tadzio's: Light (reveals hidden projectiles this round, free), Hold (blocks the first hit this round, +1 minute) or Warm (+3 Awake, +1 minute). Wick has no turn until he has joined
No
Dodge phase. The worker plays one pattern from its list (chosen in order, then looping) for its duration seconds. Patterns are GDScript classes in src/battle/patterns/, each taking a params dictionary. Required for the slice:
Pattern
Behavior
Params
rain
Projectiles fall from the top at random x
count, speed, sprite
sweep
Horizontal bars sweep across with a gap
bars, gap_px, speed, from (left/right/both)
ring
A ring expands from center; stay inside the gap
rings, speed, gap_angle
drift
Slow projectiles that steer gently toward the token
count, speed, turn_rate
dark
Arena goes black except the token’s glow; projectiles are invisible unless Wick used Light
wraps any other pattern
Rewind. Once Tadzio owns the pocket watch, press rewind during a dodge phase to roll the arena back 2 seconds. Implementation: the arena records a snapshot of token position and every projectile’s state each physics frame into a 120-frame ring buffer; rewind restores the oldest snapshot and continues. 3 charges per battle, each costs 1 minute, cannot be used during the 0.5 s after a hit (so it’s for dodging, not undoing). The first time a hit is imminent in the Curfew fight, time slows to 0.2× and a prompt teaches the button.
Worker data file
{
  "id": "unbaker",
  "name": "The Un-Baker",
  "job": "Takes yesterday’s bread back before morning",
  "sprite": "unbaker", "portrait": "unbaker", "size": "normal",
  "patience": 15,
  "hit_damage": 2,
  "patterns": [
    { "type": "rain", "duration": 6, "count": 10, "speed": 50, "sprite": "crumb" },
    { "type": "sweep", "duration": 6, "bars": 3, "gap_px": 24, "speed": 60, "from": "both" }
  ],
  "task": {
    "title": "Collect the loaves",
    "steps": [
      { "label": "Ask what the bread is for", "line": "unbaker_help_1" },
      { "label": "Carry a loaf", "line": "unbaker_help_2" },
      { "label": "Check the list", "line": "unbaker_help_3",
        "choice": { "prompt": "The list says 3 loaves. The cart has…", "options": ["2", "3", "4"], "correct": 1,
                    "wrong_line": "unbaker_help_3_wrong" } }
    ]
  },
  "dialogue": {
    "intro": "unbaker_battle_intro",
    "hustle_hit": "unbaker_hustle",
    "satisfied": "unbaker_satisfied",
    "defeated": "unbaker_defeated"
  },
  "rewards": { "satisfied": { "flag": "friend_unbaker", "item": "heel_of_bread" }, "defeated": { "flag": "enemy_unbaker" } }
}
A task step with a choice shows a prompt; a wrong answer plays wrong_line, does not advance, and still costs the minutes. Everything a worker says in battle is a dialogue id, so a new worker is one JSON file plus a handful of dialogue entries and a sprite.
Saving and what carries over
Autosave at every room transition and at night end to user://save.json. Nothing about the clock is saved; every night starts at 1:59 in bed. Saved: night (int), flags (dictionary), items (array), friends and enemies (derived from flags), seen_dialogue (array, so inspect text can vary on repeat), settings (volume, text speed, scale). One save slot for the slice. The title screen offers Continue when a save exists and New Night otherwise.
Slice content: Night 1
Nine rooms, five speaking characters, two battles, one ending. A player who talks to everyone and helps both workers should reach Curfew at about 2:40 and hit 3:00 during the final conversation. The numbers below are starting values; tune in tuning.json after playtesting.
Rooms
Id
Place
Size (tiles)
What happens
bedroom
Tadzio’s room
12×9
Wake at 1:59. Inspect: clock radio, drawing on the wall (TODO Tadzio draws it), window, closet, bed. Door to hallway
hallway
Upstairs hall
14×6
Dad’s door is closed: “He sleeps like a log. A log would be louder.” Bathroom light flickers once. Stairs down
kitchen
Kitchen
14×9
The fridge hums a tune (looping 4-note motif). Back door is unlocked, and it is never unlocked
backyard
Yard and gate
14Ù9
Cold. A small light bobs past the gate. Stepping through the gate sets the clock to 2:00 and plays the chime
street_maple
Tadzio’s street
24Ù9
Lamps dark but one. Wick under a broken ladder. Tutorial help. Trigger at the corner starts the Un-Baker encounter
street_main
Shops
28Ù9
Bakery lit at 2 AM, door locked (“Night only. You don’t have a card.”). Night Postman with a mailbag. Door to Depot
depot_exterior
Depot front
16Ù9
Big rolling door, punch clock that rejects you (NO CARD). Wick opens the side door
depot_interior
Nightshift HQ
22Ù12
The Foreman, the Help Wanted board, lost-and-found bin with the watch, time cards on the wall. Exit to the square
square
Town square
20Ù12
Town clock stopped at 2:00. Curfew boss. Ending plays here
Cast
Character
Role
Look (placeholder notes)
Voice
Tadzio
Player
Pajamas (two-tone, pattern TODO Tadzio), slippers, flashlight. 16×32
Short lines, dry, brave by default
Wick
Companion. Apprentice lamplighter, moth-person
Small, round, two antennae, oversized lamplighter’s coat, carries a pole with a flame. Flinches from the flashlight. 16×32
Fast, nervous, apologizes mid-sentence, surprisingly brave for a moth
The Un-Baker
First battle. Takes yesterday’s bread back
Tall, floury apron, pushes a cart. 16×32 + cart
Gruff, literal, counts out loud
The Night Postman
Flavor NPC. Delivers dreams in envelopes
Long coat, mailbag that glows faintly. 16×32
Whispers. Has a letter with Tadzio’s name he won’t hand over yet
The Foreman
Depot boss. Runs the shift
Wide, clipboard, visor, a pencil behind each ear. 32×32
Clipped. Everything is a schedule problem
Curfew
Boss. Puts awake kids back to bed
A heap of quilt and pillows with two sleepy eyes, 48×48. Moves like a slow wave
Slow, kind, exhausted. Speaks in lullaby cadence
Beat-by-beat
1. Bedroom, 1:59. Fade in on Tadzio sitting up. Clock radio reads 1:59 and stays there. Everything inspectable has a line; the bed says “Not yet.”
2. Hallway. Dad’s door line. Bathroom light flickers when passed (one-time trigger).
3. Kitchen. The fridge is humming. Inspecting it: “It knows a song. You have never heard the fridge know a song.” The back door opens.
4. Backyard. A light bobs past the gate. Through the gate: chime, clock snaps to 2:00, HUD clock appears, street music begins.
5. Street Maple. All lamps dark except the farthest. Wick is on the ground under a snapped ladder, trying to reach a lamp hook with his pole. wick_intro plays; he panics that a dayside kid can see him. Choice: offer to help. Tutorial: stand under the lamp and hold confirm while a bar fills; the clock ticks 2 minutes as it fills (first lesson: help costs time). The lamp lights. Wick joins, sets wick_joined, and from now on follows 24 px behind.
6. Corner trigger. The Un-Baker rolls in, taking loaves off doorsteps. “You’re not on my list. Nobody awake is on my list.” Battle unbaker. Help route: three steps, then he grunts thanks and gives a heel of bread. Hustle route: he storms off, “Tell the Foreman I’m owed a loaf.” Either way Wick comments on the outcome afterward.
7. Street Main. Bakery lit, door locked. The Night Postman is at the corner mailbox. He has an envelope with Tadzio’s name and won’t hand it over: “You get it when you’re asleep. That’s the rule.” Sets postman_met. (Future hook: the letter.)
8. Depot exterior. Punch clock: NO CARD, loud buzz. Wick, mortified, opens the side door with his pole.
9. Depot interior. The Foreman: “Not on the schedule.” Wick vouches. Foreman: “Fine. Curfew’s on the square. Curfew will sort it out.” He hands Tadzio a form; filling it out is a clock_add of 8 minutes and a joke (the form asks for a bedtime). The Help Wanted board is inspectable. The lost-and-found bin holds a pocket watch stopped at 2:00; Wick says not to wind it; winding it sets has_watch and shows the rewind charges on the HUD. If the Un-Baker was hustled, the Foreman mentions the owed loaf and the watch costs one more form (+4 minutes).
10. Square. The town clock on the tower reads 2:00. Wick notices and goes quiet. Curfew arrives as a slow wave across the square. “Up past bedtime. That’s my department.” Battle curfew.
11. Resolution. Help route: on the last step Curfew yawns enormously, says it has never once been asleep, and goes down like a dropped quilt. The town clock ticks once, audibly. Hustle route: Curfew clocks out early, grumbling, and the clock does not tick. Wick starts to say something about the clock. The HUD hits 2:59, then 3:00 mid-sentence. White out.
12. Morning. Bedroom in daylight, different palette. On the nightstand: a punch card, NIGHTSHIFT · TRAINEE · TADZIO. Inspecting it shows the Night End screen: friends made, minutes used, and the line “Night 1 complete. Same time tomorrow.” Return to title with Continue enabled (Night 2 is the same content for now, with changed first lines where seen_dialogue allows).
Curfew (boss) design
Field
Value
Patience
30
Hit damage
3
Arena
140×90, grows to 160×100 for yawn
Pattern 1: rain (lullaby notes)
12 notes, speed 45, note sprites, 7 s
Pattern 2: ring (yawn)
2 rings, speed 35, gap 50°, 7 s; pushes the arena bigger while active
Pattern 3: sweep (tuck-in)
2 bars from both sides, gap 28 px, speed 55, 6 s
Pattern 4: dark wrapping drift (lights out)
6 drifters, speed 30, turn rate 1.2; only visible with Wick’s Light
Task
“Put Curfew to bed”: (1) Ask when it last slept. (2) Fluff the pillow. (3) Hum its lullaby back: sub-choice of 3 note patterns, correct one hinted by pattern 1’s note order. (4) Tuck it in
Rewind tutorial
First imminent hit in this battle slows time to 0.2× with a prompt
Expected length
6–8 rounds on the Help route (about 14 minutes of clock), 6 rounds on Hustle
Help Wanted board. An inspectable in the Depot that reads data/help_wanted.json: a list of postings with title, posted_by, text, and status (open, taken, done). It renders as pinned cards you page through. Ships with three teaser postings (“Bakery: night counter help, must know what a croissant dreams about”; “Clock tower: someone to find out why it stopped”; “Lost & Found: too many lost things, not enough finding”) and one blank card: “YOUR POSTING HERE. Ask the Foreman.” Every posting Tadzio writes becomes a worker file later.
Art and audio direction
The slice ships with generated placeholder art so it runs on day 1; real pixel art replaces it file by file without code changes. Every sprite sheet has a fixed layout so swapping art never touches a script.
Palette (data/palette.json, the only colors allowed in night scenes)
Name
Hex
Use
ink
#0b0e1f
Deepest shadow, outlines, text box background
night
#1b1f3b
Sky, unlit ground
dusk
#2e3561
Walls, mid shadow
slate
#4b568c
Lit ground, roads
fog
#8a90b8
Highlights on stone, inactive text
moon
#f4ead6
Text, Tadzio’s pajamas highlight, moonlit edges
lamp
#ffb347
Streetlamp light, Wick’s flame, interact marker
ember
#ff7a1a
Lamp cores, warnings, Hustle hits
hush
#e05a6d
Awake damage flash, Curfew’s eyes
wake
#6cd4a8
Rewind glow, the watch, friend flags
Morning (beat 12) uses a separate 6-color warm palette: cream, butter yellow, soft blue, pale green, brown, white. It should feel like a different game for ten seconds.
Sprites and tiles
Asset
Spec
Tiles
16×16, one tileset PNG per tileset name, atlas indexed by legend names in tilesets.json
Characters
16×32 frames; sheet rows = down, up, left, right; 4 walk frames per row; frame 0 = idle. Right is the left row flipped
Large characters
Same row layout at 32×32 (Foreman) or 48×48 (Curfew, 2 idle frames that breathe)
Portraits
32×32, one PNG per expression, named <speaker>_<mood>.png
Projectiles
8×8 single frames: crumb, note, drifter, bar (1×8 stretched)
Token
6×6 bright oval with a 24 px soft glow shader
Font
A free pixel font with a permissive license, 7–9 px tall, readable at 1× (candidates: m5x7 or m6x11 by Daniel Linssen; verify the license before shipping). Do not use any font associated with Undertale
tools/gen_placeholders.py (Pillow) generates every sheet above as flat-color silhouettes from the palette with a one-pixel ink outline and a letter on the chest (T, W, U, P, F, C) so characters are tellable apart in playtests.
Lighting. Night rooms sit under a CanvasModulate at the room’s ambient value. Streetlamps are PointLight2D in lamp with a 40 px radius and a slow 2 % flicker. Tadzio’s flashlight is a 60° cone, 56 px long, toggled with menu. Lighting a lamp is a story event (light command) and persists for the night only.
Audio
Element
Spec
Dialogue blips
Short square-wave blips generated with a sfxr-style tool; one pitch per speaker in _speakers.json (Tadzio mid, Wick high and quick, Foreman low, Curfew very low and slow)
UI
Cursor move, confirm, cancel, NO CARD buzz, lamp ignition whoosh, clock chime at 2:00
Battle
Hit (soft, not harsh), Hustle timing hit, rewind (reversed tape sound), round tick
Music
Four loops, 60–90 s, OGG: house_hum (the fridge motif, sparse), street_loop, depot_loop, curfew_theme (a lullaby in 3/4). A clock tick sits in the mix as the metronome
Clock tension
Music pitch and tempo rise 3 % at 2:45 and another 3 % at 2:55 via AudioStreamPlayer.pitch_scale; HUD clock pulses ember from 2:55
Placeholder
Loops may be simple generated chiptune; replace later without code changes
Build order
Seven milestones, one per day, each ending in something playable. Each has an acceptance check that a person can do by hand in under two minutes. Do not start the next milestone until the current check passes; cut scope inside a day rather than slipping it.
1. Skeleton and overworld. Project settings, input map, autoload stubs, Player, RoomLoader from ASCII JSON, doors, spawns, NightClock with HUD, gen_placeholders.py, DEV.md.
    ◦ Check: walk from bedroom through hallway, kitchen, backyard to street_maple with placeholder art. The clock reads 1:59 indoors, chimes to 2:00 at the gate, and each door after that adds a minute.
2. Dialogue. DialogueRunner, textbox with portrait, typewriter, blips, choices, all commands in the Dialogue section, Interactable, Trigger, NPC with facing, _speakers.json.
    ◦ Check: every object in bedroom has a line; wick_intro plays with a working choice; set_flag changes an inspect line on second read; clock_add moves the HUD.
3. Battle core. Battle scene, arena, token with movement and invulnerability, Awake and Patience meters, rain, sweep, ring patterns, Hustle timing bar, Stall, round tick, transitions in and out, fall-asleep ending.
    ◦ Check: from dev/test_battle.tscn, fight a placeholder worker and win by Hustle; lose on purpose and wake in bedroom with the night ended.
4. Help, Wick, rewind, worker data. WorkerActor loading data/workers/*.json, task steps with sub-choices, Help resolution and flags, Wick sub-menu with Light and Hold, dark and drift patterns, rewind ring buffer with charges, rewards.
    ◦ Check: unbaker.json works on both routes with the correct flags and item; dark is unplayable without Light and fair with it; rewind visibly rolls back 2 s and costs a minute.
5. Night 1 content. All nine rooms, all dialogue, Wick following, lamp tutorial, Postman, Depot scenes, the watch, Curfew with all four patterns and its task, both resolutions, 3:00 cutoff, morning room, Night End screen.
    ◦ Check: play Night 1 start to finish on the Help route in 12–18 minutes, reaching Curfew between 2:36 and 2:44. Then the Hustle route. Then deliberately run out the clock before the square.
6. Shell and persistence. Title screen (New Night, Continue, Settings), SaveManager with autosave, settings (music, SFX, text speed, window scale, fullscreen), Help Wanted board UI, credits screen listing the designers, Windows and macOS export presets.
    ◦ Check: quit mid-night, relaunch, Continue starts a fresh 1:59 with flags kept; exported builds run on a machine without Godot installed.
7. Tuning and polish. Playtest log, adjust tuning.json against the 2:40 target, fix bugs, replace the ugliest placeholders, add screen shake and hit flashes, confirm gamepad end to end. Buffer for anything that slipped.
    ◦ Check: a first-time player who has not read this spec finishes Night 1 without help and can say what the watch does.
If something has to go, cut in this order: drift pattern, the Postman, settings beyond volume, morning palette, Night 2 dialogue variants. Never cut: the clock, the Help route, Wick, the Help Wanted board, the 3:00 cutoff.
Out of scope for the slice
These are deliberately not built this week. Leave hooks (flags, empty data folders, TODO markers) where cheap, but do not implement.
• Items menu and item use in battle. give_item records items; nothing consumes them yet.
• Night 2 and beyond as distinct content. Continue replays Night 1 with seen_dialogue variants.
• The minute-eater mystery, the letter, the bakery interior, the clock tower.
• Steam SDK, achievements, cloud saves. Keep saves in user:// so this is additive later.
• Localization. Keep all strings in data/ so it stays possible.
• Real-time clock ticking. Deterministic only, unless playtests prove the overworld feels slack.
• Multiple save slots, difficulty options, accessibility beyond text speed and window scale.
• The website version. If built later, it should import the same data/ files unchanged.
Working conventions for Claude Code
• Start by reading this spec in full, then create DEV.md with: how to run, debug keys, and a worked example of adding a new worker. Keep it current.
• Build in the milestone order above. One commit per completed check at minimum, with the check named in the message.
• GDScript with static typing everywhere. One scene per system. Signals over direct references between systems. No global state outside the five autoloads.
• Every system gets a scene in dev/ that exercises it in isolation. Those scenes are how the human tests between milestones.
• All player-facing text lives in data/. If you find yourself writing dialogue in a script, stop and move it.
• Loaders validate JSON at startup and report file: field: problem in the Godot output and on screen in debug builds. A kid will edit these files.
• Debug keys in debug builds only: F1 add 10 minutes, F2 give the watch, F3 start the Curfew battle, F4 toggle all flags listed in dev/flags.txt, F5 reload the current room from JSON, F11 fullscreen.
• Placeholder art comes from gen_placeholders.py. Never hand-draw pixels in code. Keep sheet layouts exactly as specified so final art drops in.
• Where this spec leaves content open, add it as TODO(Tadzio): … in the data file or a short placeholder line, not invented lore. The kid fills those in.
• Nothing borrowed from Undertale or Deltarune: no names, lines, sprites, fonts, sounds, or UI labels. If a detail feels like a quote, change it.
• Kid-safe throughout: no blood, no death, no insults aimed at the player. Losing is falling asleep.
• When a milestone check fails, fix the cause before adding anything new. When a decision is not covered here, choose the simplest option that keeps content in data files, and note it in DEV.md under Decisions.

---

# Round 2 (2026-11-04)

Design direction from the lead designer, Tadzio: the town forgets every day, and only what
you save stays. You can look for fights on purpose. When you beat someone, you choose to
let them go or to finish them. Finishing makes you stronger, so the choice is hard, and it
decides who you are.

## Save model

This section replaces the autosave rule in v0.1.

Live state is the state of this session: flags, items, hours, the workers who are gone,
friends, enemies, and the tallies `helper_count`, `hustler_count` and `finished_count`.
`Game` holds it. Committed state is what is on disk in `user://save.json`. Pending state is
what live state has and committed state does not.

Lamps are save points. A lamp is a room entity of type `lamp` with an `id`. The flag
`lamp_<id>` is its lit state. A dark lamp is lit by Wick when he is in the party. The lamp
on Maple Street is the tutorial: the player holds Confirm to light it, as before. A lamp
with `"wick": false` lights when the player interacts with it. Lighting costs 2 minutes
(`costs.lamp`). Then the prompt "The lamp remembers. Save here?" opens. Save commits live
state to disk. Interact with a lit lamp to save again. The lit flag is part of the
committed state, so a lamp that was not saved is dark again next night.

There is one lamp in each outdoor room on the route (Maple Street, Main Street, the Depot
yard, the square and the alley) and one in the Depot. There are no lamps in the house.

When the night ends (3:00, the `end_night` command, or falling asleep), live state reverts
to committed state. Then the "What the lamps remember" screen shows two columns. Kept is
what the last save holds. Forgotten is what was pending. Each column names friends,
enemies, workers who are gone, items, hours and the number of lamps lit. Then the morning
room plays. The morning comes after the revert, so the punch card is kept. The Night End
card commits the next night number.

Flags that start with `tonight_` never save. Seen dialogue saves and reverts with the rest.
Continue on the title loads committed state. Debug key F6 commits now.

`Game.time_state` is `EVENING` (the house before 2:00), `NIGHT` (the clock runs) or
`MORNING` (after the night ends). It is the hook for the alarm clock in the next round.

## Spare or finish

A fight ends in one of four ways, and all four go through `Battle._resolve`:

| Outcome | How | Result |
|---|---|---|
| satisfied | Help finishes the task | `friend_<id>`, the worker's `rewards.satisfied.item`, `helper_count` + 1 |
| spared | Hustle takes all Patience, then "Let them go" | The worker storms off. `enemy_<id>`, 1 hour (0 for a worker worth 0), `hustler_count` + 1 |
| finished | Hustle takes all Patience, then "Clock them out" | The worker goes still, flickers twice and is gone. The lantern behind them goes out on one low note, and the frame holds for one second. `gone_<id>`, the worker's full `hours`, `finished_count` + 1 |
| abandoned | Awake reaches 0, or 3:00 | Asleep ends the night. No flags |

When Patience reaches 0 by Hustle, the fight stops and the choice opens. Help is not
offered again. The two verbs are placeholders (`TODO(Tadzio)` in `data/ui.json`). Each
option shows the hours it gives. Finishing is quiet and final: no blood, no sound of pain,
no scream.

## Hours and Shift Level

Hours are experience. Every worker file has `hours`: the dummy 0, the Un-Baker 6, posted
workers 8, the alley boss 15, Curfew 25. Helpers gain no hours.

Shift Level comes from `shift_levels` in `tuning.json` (0, 10, 25, 45, 70 hours for
levels 1 to 5). Each level after 1 adds `level_awake` (4) max Awake and `level_hustle` (1)
Hustle damage. The battle shows `Shift Lv n` above Awake. The Night End card shows the Shift
Level, the hours and the path.

The path is the largest of `helper_count`, `hustler_count` and `finished_count`, with ties
to the later one. Its placeholder names are Helper, Hustler and Overtime (`TODO(Tadzio)`).

A helper's power is friends. A satisfied worker gives an item. Pockets, the fifth battle
button, lists the items that do something in a fight; using one takes the turn. The
Un-Baker's heel of bread restores 8 Awake.

## Workers who are gone

A gone worker never comes back, and the town shows that the job is undone. Room entities
and tile overrides take `if_gone` and `unless_gone` with a worker id. Dialogue lines check
the `gone_<id>` flags. When the Un-Baker is gone, his bread stays on the doorsteps of
Maple Street and his cart stands there with nobody pushing it.

The first time a worker is finished, Wick says a line in the fight. When two or more
workers are gone (the flag `many_gone`), Wick says quieter lines at the Depot and at
Curfew. The Foreman names every missing worker when Tadzio enters the Depot and when he
talks to the Foreman. All of these lines are placeholders with `TODO(Tadzio)` markers.

## Encounters

Fights can be found on purpose. A worker stands at a post every night, and a room entity of
type `encounter` puts them there: `worker`, `x`, `y`, `approach` (a dialogue id) and
`respawn` (`nightly` or `never`). When Tadzio walks within `radius` tiles (default 2), or
presses Confirm at the worker, the approach line plays and the fight starts.

After the fight:

- Satisfied: the worker stays at the post and does the job. A friend does not fight
  again; Confirm plays their `chat` line.
- Spared: the worker leaves for the rest of the night (the flag `tonight_left_<id>`). The
  next night they are back at the post and angry (`approach_enemy`), and they fight again.
- Finished: gone for good. The post light (`light`) goes out, and the room shows the job
  that nobody does.
- With `"respawn": "never"`, the worker leaves for good after any outcome.

The slice has four encounters. The practice dummy stands in the backyard; a fight there
comes before 2:00, so it costs no minutes. On the way to Curfew there are three: the
Un-Baker on Maple Street, the Window Washer on Main Street, and the Puddle Keeper outside
the Depot. The Window Washer washes the reflections out of windows so sleepers do not see
themselves; when the Window Washer is gone, a shop window shows Tadzio his own face. The
Puddle Keeper keeps the night's puddles from drying before morning; when the Puddle Keeper
is gone, the puddles are dry. Both are placeholders for Tadzio to rename or replace, and their files are small on
purpose so they work as examples.

## Secret rooms

The town hides things. A room entity of type `false_wall` sits on a wall tile. In the dark
it is the room's own wall and it is solid. Inside the flashlight beam (56 px, 60 degrees)
it shows its `tile`, a gap, and the gap is walkable. Walking into the gap goes to the room
in `to`, like a door. There is no label and no marker.

The flashlight starts off every night. The bedroom names its key once. A player who never
turns it on never finds the gap. The flashlight is for finding secrets, not for seeing.

On Main Street, between two shops, a false wall opens on `alley_1`: a small dead end with
one lamp and something that is not a worker. It has no name tag and no job; its
placeholder name is "the one with no job" (`TODO(Tadzio)`). Patience 24, hit damage 3,
three patterns (drift, ring, and a dark sweep), 15 hours. Its Help task is three steps,
and each step is a question it asks; any answer counts. Every outcome leaves behind the
same item, a key to nothing. It has `"respawn": "never"`: once the fight is over, any way,
the alley is quiet, and the lamp still works. The alley lamp lights without Wick
(`"wick": false`). The game never explains any of it.

---

# Round 3: graphics and readability (2026-11-04)

The playtester could not tell what things were. Told to go to the door or the clock, he
could not find either. This round replaces the placeholder art with drawn pixel art, and
sets rules so that everything reads the same way.

## Art

All art is text in `assets/px/`, one letter per pixel, and `tools/compile_px.py` builds the
PNGs. DEV.md, "Art and sound", has the file format. No PNG is edited by hand.

Each art file names, in its header, the list entry of this round it belongs to and the
rules it follows, so a reviewer can check it:

    # clock_radio 16x16
    # item: bedroom set
    # rules: viewpoint, outline, warm, hero, motion

The rules, with the short name a file header uses:

1. **viewpoint.** Front-facing three-quarter view, the same for every object. Nothing is
   drawn from directly above.
2. **outline.** Every character and every thing you can interact with has a one-pixel
   `ink` outline. Scenery tiles do not. That difference alone separates things from
   background.
3. **warm.** Warm means touchable. Every interactable has at least one cluster of `lamp`
   or `moon` pixels: a knob, a dial, a glow. Scenery stays in the cool colors.
   `tools/compile_px.py` refuses art that breaks this rule.
4. **walls.** A wall has a visible top edge in `fog` and a darker face in `dusk`. A floor is
   `slate` with low-contrast texture. With the game paused, a player can tell walkable
   from blocked at a glance.
5. **doors.** A door always sits in a wall, with a frame, a knob in `lamp`, and a dark
   inside. A room exit at the edge of the screen has a visible gap in the wall, never an
   invisible trigger.
6. **hero.** Props the story names are drawn bigger than life. The clock radio is 16x10
   with a readable 1:59. The fridge is two tiles tall.
7. **motion.** Anything the story names moves: the colon of the clock radio blinks, the
   fridge wobbles on the beat of its hum, lamps flicker, the light of the punch clock
   pulses. Two frames are enough. Motion means "this matters".
8. **characters.** Characters are 16x32, with silhouettes you could tell apart as black
   shapes: Tadzio narrow with a flashlight, Wick round with antennae and a pole, the
   Un-Baker tall with a hat and a cart, the Foreman wide, Curfew a heap. Three to four
   colors each, plus the outline. In a fight, each worker uses a battle sheet
   `<sprite>_battle` at 2x to 3x (32x64 to 48x96) with two idle frames. Curfew, the
   boss, is larger (64x80). No letters on chests.
9. **lighting.** The ambient light of a night room is never below 0.9. The flashlight is
   for finding secrets, not for seeing the room. The validator reports a darker room.
10. **portraits.** Portraits are 32x32, with the same outline rule and one clear
    expression each.
