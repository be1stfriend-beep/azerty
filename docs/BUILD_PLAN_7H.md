# BUILD_PLAN_7H: replaces BUILD_PLAN.md

7 hours total. This file overrides SPEC §3.9 (story), §8 (scope) and the old step list. Everything else in SPEC.md and CLAUDE.md still applies.

## 1. What we build in 7 hours (the cut)

**In:** two phones connect; both characters move; mount/dismount; Imad aims and grabs trash from Bjorn's back; one Recycler; one Bench with 2 recipes (Filter, Broomstick); one Tower whose activation brings colour back; the cockroach lure-and-ambush; a dialogue line at start and end; Net Meter overlay.

**Out (do not build, do not discuss):** prologue cards, Act 1 split areas (both spawn together in the Dome), cutscenes (use dialogue box text only), Mask, Battery, Tower 2, industrial zone (the gate just opens and the radio line plays), session stats card, music (2 SFX only), WebSocket transport, pause menu, save.

**Content size:** 5 trash types (bottle, can, cardboard, apple core, plank), 4 materials (plastic, metal, paper, compost, wood: 5 total), 1 level JSON.

## 2. Timeline

| Time | Claude Code (one session each, plan mode) | Editor human (parallel) | Free AI agent (parallel) |
|---|---|---|---|
| 0:00 to 0:45 | **S1** Skeleton, Data, style shader, level loader, greybox level | E0 verify Godot and phone deploy. E2 download props. Start E5 server | Write `items.json`, `recipes.json`, `dialogue.json`, `balance.json` from SPEC §3 |
| 0:45 to 1:45 | **S2 ★** Net core + players + camera + touch | E3 scan assets, prune prefabs. Test S1 visually | Review S2 diff |
| 1:45 to 2:00 | **Gate G1:** two phones see each other move | | |
| 2:00 to 3:15 | **S3 ★** Mount + rider aim + tongs | Test on two phones, screenshot QA | |
| 3:15 to 3:30 | **Gate G3:** 20 mount cycles, Imad grabs while Bjorn walks | | |
| 3:30 to 4:30 | **S4** Economy, air, tower, HUD | Run server test from a phone on 5G | UI polish fixes only |
| 4:30 to 5:45 | **S5 ★** Cockroach + pillar + perch + broom | Test | |
| 5:45 to 6:00 | **Gate G5:** lure-and-ambush works with 2 players | | |
| 6:00 to 7:00 | **S6** Dialogue lines, Net Meter polish, Android export. **Freeze at 6:00: bug fixes only** | Release APKs, record demo video, test dedicated server | |

If a gate is not passed by its time plus 30 minutes, apply the fallback in §4. Do not start the next step.

## 3. Sessions

Prompt template:

> Read CLAUDE.md, docs/SPEC.md §[X] and docs/BUILD_PLAN_7H.md session [Sn]. Do only that session. Plan in 10 lines max, wait for OK, then implement. Finish with manual test steps and 5 lines of anything unfinished.

**S1 · Skeleton and style (SPEC §4.3, §5).** Folders, `project.godot` (Compatibility, landscape, Input Map, 6 autoload stubs, INTERNET permission), `Data` loader, `Events`, `tools/validate_data.py`, `tools/scan_assets.py`, `world_style.gdshader` with 3-step cel, rim light and tower restoration uniforms, `Style.apply(node)`, `EntityFactory`, `LevelLoader`, greybox `levels/main.json` (Dome, wasteland patch, 1 pillar, 1 perch, 1 gate, 12 trash, 1 recycler, 1 bench, 1 tower), procedural fallback props for all 5 trash types.
Accept: level loads, all props styled, restoration test key animates colour.

**S2 ★ · Net, players, camera (SPEC §2, §6).** `Net` with ENet transport, host, join, headless dedicated mode, role assignment, disconnect handling, code-built lobby, `NetMeter`. `CharacterBuilder` (primitives, spring wobble, simple faces), `bjorn.gd`, `imad.gd` (crawler cart), synced movement with interpolation, jump, follow camera with leash, touch joystick and buttons.
Accept: two instances and two phones see each other moving; dedicated server runs headless.

**S3 ★ · Mount and split control (SPEC §3.8, §6.3, §6.5).** `MountController` with all edge cases, merged movement from Bjorn's client, Imad at Saddle, rider aim (unreliable ~20 Hz), `use_tool`, server-validated tongs pickup, carry capacity 8, contextual touch buttons per role and mount state.
Accept: 20 mount cycles clean; Imad grabs trash from Bjorn's back while Bjorn walks. Use Opus for this session if the plan looks shaky.

**S4 · Economy, air, tower.** `TeamState` replicated stash, carried, air and tower flags. `Recycler` and `Bench` as `Station` subclasses, code-built craft menu, 2 recipes from JSON, air drain and refill, knockout and respawn, `Tower` hold-to-activate calling `Style.restore()`. Minimal HUD (air bar, carried count, tool).
Accept: collect, recycle, craft Filter, activate tower, colour returns on both phones.

**S5 ★ · Cockroach.** Server-only state machine (Idle, Chase, WindUp, Charge, Stunned, Flee), pillar stun, perch dismount point, broom hit, 3 hits to flee, gate opens. Clients render with procedural leg animation and a clear windup tell. No scripted chase.
Accept: lure-and-ambush works with two real players at 80 ms fake latency.

**S6 · Finish.** Dialogue lines (start, merge, end, radio) in a text box, 2 SFX (grab, tower), Net Meter toggle, Android debug and release export, `tools/export_server.sh`.
Accept: clean install runs start to ending twice.

## 4. Fallbacks (decide at the gate, not later)

| If | Then |
|---|---|
| G1 fails at 2:30 | Drop the dedicated server and the room code. LAN or hotspot listen-server only, join by IP. Fix movement first |
| G3 fails at 4:00 | Simplify mount to instant attach with no animation and no blocked-dismount handling |
| No VPS by hour 4 | Run the dedicated server on a laptop joined to a hotspot with both phones |
| G5 fails at 6:30 | Cut the perch. The cockroach is stunned by the pillar and Imad hits from the back of the merged body |
| Style shader eats time in S1 | Ship flat palette materials and skip tower colour restoration |
| A model looks off-style | Delete its prefab entry. The procedural fallback takes over |

## 5. Rules for the 7 hours
- One Claude Code session at a time. `/clear` between. Check `/usage` before each. If under about 8% daily remains before an ★ session, give the next step to a free agent with the same CLAUDE.md.
- Editor human tests every session on two instances before the next starts.
- No new ideas after 3:00. Write them in the backlog line: *Boots, Mask, Battery, Tower 2, prologue, sorting bonus, WebSocket, session stats.*
- Record a screen video of any working run as soon as G5 passes. It is the demo fallback.
