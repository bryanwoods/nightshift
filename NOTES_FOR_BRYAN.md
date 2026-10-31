# Notes for Bryan

Things I decided without you, ranked by how much they change the game.
Each one is easy to undo. The full list of small decisions is in DEV.md, Decisions.

## Check these first

1. **The 2:40 target.** The spec's own costs reach Curfew at about 2:22. To get closer, street-to-street doors cost 3 minutes, and after Wick joins, five dark lamps are optional hold spots (+2 min each). The bot lights 2 of them and reaches the square at 2:32. Lighting all 5 gives about 2:38. Knobs: `minutes` on the street doors, the `hold` entities in the street rooms, `data/tuning.json`.
2. **Night 2 is a replay with flags kept.** Wick already follows you, the Un-Baker is not fought again (his flag carries over), the Foreman's form and the Curfew fight play again. Flags that start with `tonight_` reset every night. Is that the carry-over you want?
3. **Wick's last line.** At 3:00 he is cut off on "the minutes, somebody's been—". It hints at the minute-eater without naming it. Too much, or right?
4. **Font.** Micro 5 (SIL OFL) instead of m5x7. I could not find an m5x7 download with a license I could check. Swap the file in `assets/fonts/` and `assets/theme.tres` if you have it.
5. **Curfew's lights-out pattern** comes 4th, so a clean Help route never sees it (3 dodge phases). The Hustle route does. Move it earlier in `data/workers/curfew.json` if every player should meet it.

## Things for Tadzio (search `TODO(Tadzio)`)

- The drawing on the bedroom wall (`data/dialogue/home.json`, `bedroom_drawing`).
- Who lives next door (`inspect_neighbor_door`).
- The credits list (`data/credits.json`).
- The pajama pattern (art; the placeholder is stripes).
- His own Help Wanted card (`data/help_wanted.json`, the blank card).

## Not done

- **Exported builds.** `export_presets.cfg` has macOS and Windows presets, but no export templates are installed on this Mac (about 1 GB from Godot's site). Then: `Godot --headless --path . --export-release macOS build/macos/Nightshift.zip`.
- **Commits per milestone.** I built the slice in one pass and tested it with a bot, so the history has a few large commits, not seven milestone commits.
- **Un-Baker's cart.** There is no cart sprite yet.
- **Real playtest.** The bot proves the routes work and the clock adds up. It cannot tell if it is fun or if a kid can finish it without help. That is your 15 minutes.

## Ideas I skipped (say the word)

- Wick flinches when the flashlight points at him.
- Footsteps and a small "minutes spent" pop on the HUD when the clock jumps.
- A cart for the Un-Baker that he pushes around.
