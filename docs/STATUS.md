# STATUS (written by R1, 2026-11-22)

Evidence is from grep over `core/`, `game/`, `data/`, `tools/`, `main.gd`, not from memory.
`python tools/check.py` result at time of writing: `boot OK | data OK | autotest 16 PASS 0 FAIL 0 engine errors`.

## Repository audit
- `project.godot`: exactly one, at the root. No nested or duplicate projects.
- `export_presets.cfg`: none (no Android preset yet; the human creates it in the editor).
- `.godot/`: one, at the root (ignored by `.gitignore`).
- `core/`, `game/`, `data/`, `shaders/`: one copy each, at the root. Nothing moved, so no `_duplicate_backup/`.
- `run/main_scene="res://main.tscn"` once. Autoloads: Style, Data, Events, Net, TeamState, Game, in order, no duplicates.

## Prompts P1 to P8 (docs/PROMPTS.md)
| Prompt | Status | Evidence |
|---|---|---|
| P1 Foundation and Data | DONE | `core/data.gd` getters item/recipe/balance/prefab/entity/dialogue/level; `core/characters.gd`; `core/input_setup.gd register()`; `core/events.gd`; all data files; `tools/validate_data.py`, `tools/run_two.py` |
| P2 Style and Greybox | DONE | `core/palette.gd`; `shaders/world_style.gdshader`, `ground.gdshader`, `vignette.gdshader`, `restore.gdshaderinc`; `Style.material/apply/set_tower/restore`; `proc_props.gd`; `entity_factory.gd spawn()`; `level_loader.gd`; `--dev-level` in `main.gd` |
| P3 Networking and Lobby | DONE | `game/ui/lobby.gd`; `Game.start_match()`, `return_to_lobby()`; "Partner lost" overlay; `net_meter.gd` with `set_line` and `pop_statistic` kbps |
| P4 Players, Camera, Touch | DONE | `character_builder.gd` (Saddle, `update_wobble`); `player_base.gd`, `bjorn.gd`, `imad.gd`; `follow_camera.gd`; `touch_controls.gd` (touchscreen or `--touch`) |
| P5 Mount, Aim, Tongs | DONE | `team_state.gd` request_* pattern; `mount_controller.gd` (SOLO/MOUNTING/MERGED/DISMOUNTING, free-spot query, partner_lost); `request_use_tool`, `request_tool_next`; mount cycle count on the meter |
| P6 Economy, Air, Tower | DONE | `interactable.gd`, `recycler.gd`, `bench.gd`, `craft_menu.gd`, `tower.gd`, `air_system.gd`, `hud.gd`; `request_recycle/craft/hold`; invention card |
| P7 Cockroach Boss | DONE | `cockroach.gd` (Idle, Chase, WindUp, Charge, Stunned, Flee), `state_machine.gd`, `roach_builder.gd`, `roach_targets.gd`, `on_perch`, broom hit, `gate.gd` |
| P8 Story and Finish | DONE | `dialogue_box.gd`, `story.gd`, "To be continued" card with Restart in `game.gd`, `docs/RUN.md` |

## Prompts P9 to P16 (docs/PROMPTS_2.md)
| Prompt | Status | Evidence |
|---|---|---|
| P9 Test harness | DONE | `game/debug/screenshot.gd` (`--screenshot`, `--cam`), `game/debug/autotest.gd`, `tools/check.py`; shots in `builds/shots/` |
| P10 Bug fixes, Bjorn's role | DONE | flee to spawn in `cockroach.gd`; `roach_perch_hit_range`; perch lock and "Climb down" prompt; `air_sync_hz`; knockout drops (`drops`, `knockout_drop_radius`, `trash_hider.gd`); bait rules in `roach_targets.gd`; FPS and draws on the meter |
| P11 Co-op puzzles | DONE | `plate.gd` (latched), `door.gd` (links), `vent.gd`, `proc_puzzle_props.gd`; 7 plate/door/vent entries in the level; link checks in `validate_data.py`; `autotest_puzzles.gd` PASS lines |
| P12 Juice | MISSING | no `core/sfx.gd`, no `AudioStreamWAV`, no `CPUParticles3D`, no camera shake, no bench invention preview, no floating "+1" text (only the roach's own hit shake from P7) |
| P13 Onboarding | MISSING | no `game/ui/hint_box.gd`, no `data/hints.json` |
| P14 Real 3D models | MISSING | packs are present in `assets/models/`, but no `tools/scan_assets.py` and every `prefabs.json` entry has `"model": null` |
| P15 Content depth | MISSING | no `mask`, `tongs_plus`, `boots` recipes, no sprouts |
| P16 Final polish | MISSING | not started (check.py is green, but no budget pass, no MultiMesh, no visibility ranges) |

## Stubs, TODOs and dead code
- TODO / FIXME / HACK markers: none.
- Unreferenced functions, classes or signals (script scan over `core/`, `game/`, `main.gd`): none.
- `pass` bodies: `Interactable.interact/release` and `PlayerBase._action_input/_on_remote_state` only. These are virtual hooks overridden by subclasses, not stubs.
- Debug prints left: `core/net.gd` (7 connection logs; file is protected, left as is). Prints in `game/debug/` are the harness output and are intended.
- Scripts over the ~200 line guideline: `net.gd` 215, `autotest.gd` 218, `team_state.gd` 209, `game.gd` 206, `cockroach.gd` 205.
- `builds/shots/` contains `.png.import` files: Godot imports `builds/` because it has no `.gdignore`. Harmless (the folder is git-ignored).
