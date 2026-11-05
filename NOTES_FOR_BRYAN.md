# Notes for Bryan

Things I decided without you, ranked by how much they change the game.
Each one is easy to undo. The full list of small decisions is in DEV.md, Decisions.

## Round 2 (2026-11-04): check these first

1. **The round before this one was skipped.** Its brief (readability, realtime clock, Wick tutorial, crafted opening, Un-Baker rework) never reached me. The realtime clock does not exist; the clock still moves only on actions.
2. **The flashlight starts off every night.** The check "a player who never turns the flashlight on never finds the alley" needs it. The bedroom names the key once. The streets are darker now.
3. **Friends give their item once.** A helped worker does not fight again and gives the item only the first time. The hustler earns hours every night by sparing, so the helper path may feel thin. A nightly refill from friends would be one dialogue line each.
4. **Friends do not fight again.** The brief says "each is back the next night unless finished". I read that as: back at the post, but a friend only chats.
5. **The practice dummy is in the backyard**, before 2:00, so practice fights cost no minutes. It gives 0 hours, also when spared.
6. **Lighting a lamp costs 2 minutes; saving is free.** The save prompt opens right after a lamp lights.
7. **The Un-Baker stands at his post** with his cart and a lantern from the start of the night, so the "cart" item under Not done is done.

## Round 2 playtest script

Use a debug build (`Godot --path .`) so F1 to F6 work. Choose New Night each time.

1. **Save model.** Light the Maple lamp with Wick and choose Not now. Help the Un-Baker. Press F1 until 3:00. The lamps screen lists the Un-Baker and Wick under Forgotten. Continue: Wick is a stranger again. Now do it again, but after the Un-Baker, save at the Main Street lamp. At 3:00 both are under Kept, and next night Wick follows you and the Un-Baker chats.
2. **Spare or finish.** Hustle the Un-Baker to 0 and choose Clock them out. He flickers twice and is gone, his lantern goes out, +6 hours, and Wick speaks. Save at the Main Street lamp, F1 to 3:00, Continue. On Maple: no Un-Baker, bread on three doorsteps, his cart alone, Wick says a line near it. In the Depot the Foreman names him. The battle and the Night End card show Lv 1 with 6 hours. Then a New Night, and choose Let them go instead: save, Continue, and he is back at his post and angry.
3. **Encounters.** From the gate, walk east without stopping. The Un-Baker (Maple), the Window Washer (Main Street, at a shop window) and the Puddle Keeper (outside the Depot) each start a fight when you walk close. Spare one, help one, finish one, save, and come back the next night: spared is back and angry, helped chats, finished is gone (the puddles are dry, or a window shows your reflection).
4. **Secret alley.** On Main Street, walk past the shops with the flashlight off: nothing. Press C and face the plain wall between the two shop windows just east of the Window Washer (tile x 21): a gap opens. Walk in. Fight the thing at the end, light the lamp (no Wick needed), save, F1 to 3:00, Continue. The key to nothing is under Kept and in your pocket, and the alley is quiet.

Every check also runs headless: `Godot --headless --path . res://dev/autotest.tscn -- route=forget`, then `finish`, `encounters`, `alley`.

## Round 1: check these first

1. **The 2:40 target.** The spec's own costs reach Curfew at about 2:22. To get closer, street-to-street doors cost 3 minutes, and after Wick joins, five dark lamps are optional hold spots (+2 min each). The bot lights 2 of them and reaches the square at 2:32. Lighting all 5 gives about 2:38. Knobs: `minutes` on the street doors, the `hold` entities in the street rooms, `data/tuning.json`.
2. **Night 2 is a replay with flags kept.** Wick already follows you, the Un-Baker is not fought again (his flag carries over), the Foreman's form and the Curfew fight play again. Flags that start with `tonight_` reset every night. Is that the carry-over you want?
3. **Wick's last line.** At 3:00 he is cut off on "the minutes, somebody's been—". It hints at the minute-eater without naming it. Too much, or right?
4. **Font.** m6x11 by Daniel Linssen (the spec's pick), "free to use with attribution" per its itch.io page. It is in the credits.
5. **Curfew's lights-out pattern** comes 4th, so a clean Help route never sees it (3 dodge phases). The Hustle route does. Move it earlier in `data/workers/curfew.json` if every player should meet it.

6. **Hustle wins every fight (playtest 2026-11-04).** Tadzio chose Hustle on 10 of 11 turns and hit the center on 9 of 10 presses. Hustle costs 0 minutes, and Help costs 2. Is this the game he wants, or must Help pull harder? Knobs: `costs.hustle`, `hustle.center_zone` (0.22) in `data/tuning.json`.
7. **The slice is short for a fast player.** Tadzio finished in 7:40 real time (the spec says 15) and reached Curfew at 2:28 (target 2:36 to 2:44). They lit 1 optional lamp.

8. **Tadzio's look and two new colors.** Tadzio is drawn from your photo. Matching his hair took two colors outside the spec's palette (`straw`, `honey` in `data/palette.json`).

## Things for Tadzio (search `TODO(Tadzio)`)

- The drawing on the bedroom wall (`data/dialogue/home.json`, `bedroom_drawing`).
- Who lives next door (`inspect_neighbor_door`).
- The credits list (`data/credits.json`).
- The pajama pattern (art; the placeholder copies the white-and-teal shirt from the photo).
- His own Help Wanted card (`data/help_wanted.json`, the blank card).

## Not done

- **Exported builds are local only.** `build/macos/Nightshift.app` and `build/windows/Nightshift.exe` exist on this Mac (export templates for 4.7.2 are now installed). `build/` is not in git. The Windows exe is not tested on a Windows machine. The Mac app is ad-hoc signed, so on another Mac it needs right-click, Open.
- **Commits per milestone.** I built the slice in one pass and tested it with a bot, so the history has a few large commits, not seven milestone commits.
- **Real playtest.** The bot proves the routes work and the clock adds up. It cannot tell if it is fun or if a kid can finish it without help. That is your 15 minutes.

## Ideas I skipped (say the word)

- Wick flinches when the flashlight points at him.
- Footsteps and a small "minutes spent" pop on the HUD when the clock jumps.
