# PROMPTS_2: Piggyback Planet, improvement round (P9 to P16)

How to use: in Claude Code, type exactly
`Read CLAUDE.md and the "Global rules" section of docs/PROMPTS_2.md, then do ONLY prompt P<n> in docs/PROMPTS_2.md.`
Run `/clear` between prompts. Each prompt assumes P1 to P8 are finished and committed.
Coordinates and collision layers are the same as in docs/PROMPTS.md.

---

## Global rules (apply to every prompt in this file; they override older docs)

1. **Roles are strict.**
   - **Bjorn (No Hands):** run, jump, kick. He never grabs, never uses tools, never deals damage. His kick only pushes light props (`kickable` flag) and plays an animation. His value is speed, jumping, reaching high ledges, luring enemies, carrying Imad.
   - **Imad (No Legs):** crawls slowly, no jump, owns every tool (tongs, broomstick, crafting, recycling, tower activation, valves, interact). The only damage in the game is Imad's broom.
   - **Merged:** Bjorn steers, Imad aims and uses tools (unchanged).
2. **Co-op puzzles**: every puzzle must be impossible for one player alone and solvable by two, using the two skill sets above.
3. **Nothing gets thrown away** (the hackathon theme): carried trash is never deleted. On knockout it drops at the knockout spot as pickable trash.
4. Listen server on a PC host, phones on the same network, UDP 7777. No VPS, no room code, no WebSocket.
5. Everything in CLAUDE.md still applies: static typing, JSON data, numbers in `balance.json`, procedural fallback for every model, scripts under about 200 lines, commit at the end.
6. Do not ask questions. Decide, implement, list under "Assumptions".
7. Use `GODOT_BIN` for every check. For visual checks use the screenshot flag from P9 (it needs a real window, not `--headless`).

---

## P9 · Test harness (gives Claude Code eyes)

1. `--screenshot <frame> <path>`: after `<frame>` frames, save the viewport to `<path>` (PNG) then quit. Works with `--dev-level`. Add optional `--cam x,y,z,tx,ty,tz` to place the dev camera.
2. `--autotest`: single process, no second instance. The host runs the server-side request functions directly, acting as both characters with fake peer ids, with no input simulation. Steps, each printing `PASS <step>` or `FAIL <step> <reason>`:
   mount/dismount x20 (assert state returns to SOLO each time), pickup of 3 trash, recycle, craft `filter` (give the needed materials through TeamState first, state it in the log), tower activation, air drain and knockout respawn with trash dropped (after P10), then quit with exit code 1 if any FAIL.
3. Add `tools/check.py`: runs `--headless --quit-after 120`, validate_data, then `--autotest`, prints one summary line.
4. Take screenshots of the dev level from three camera positions (overview, Dome, pillar and perch). Look at them and write at most 8 lines on what looks wrong visually (floating props, unreadable silhouettes, grey materials, characters not contrasting with the ground). Fix only obvious bugs in the same prompt.

Done when: `python tools/check.py` prints all PASS and the three screenshots exist in `builds/shots/`.

---

## P10 · Bug fixes and Bjorn's role in the boss fight

Fix, with the smallest change each:
1. **Roach flee direction.** It spawns at z=52 (south) and must not cross the Dome. Flee toward its spawn marker, then remove it.
2. **Perch reach.** Compute the real distance from the perch top to the roach's stun position (it stops about 2.5 m before the pillar). Move the perch or raise `roach_perch_hit_range` in `balance.json` so a broom hit from the perch always lands. Write the computed numbers in the final message.
3. **Imad on the perch** cannot walk off: movement locked until he remounts. Add a visible "Climb down" prompt.
4. **Air sync.** Air must not be replicated by reliable RPC every frame. The host ticks it, replicates at 4 Hz (unreliable) and on state change (reliable). Use `balance.json` key `air_sync_hz`.
5. **Knockout** drops `carried` trash at the knockout position as pickable trash entities (same ids as the originals, spread in a 2 m ring), instead of deleting. Update the "Out of air" message.
6. **Bjorn as bait.** Roach target choice prefers Bjorn whenever both players are valid targets, unless Bjorn is more than 25 m away. A player on the perch is never a target. While Imad is holding a tower activation, the roach goes after Bjorn only if Bjorn is within 20 m of the tower, otherwise it ignores the tower.
7. Add FPS and draw calls to the Net Meter (`Performance.get_monitor` TIME_FPS and RENDER_TOTAL_DRAW_CALLS_IN_FRAME).

Done when: `python tools/check.py` is green and the roach no longer enters the Dome.

---

## P11 · Co-op puzzles (data-driven)

Build a small puzzle framework, then two puzzles that also fix the economy (more compost and metal).

Framework (host authoritative, state in TeamState, ids deterministic `<kind>_<index>`):
- `plate`: pressure plate, active while any player stands on it. Optional `latched: true` (stays on).
- `door`: a slab with `links: [plate ids]`, opens (slides down) when all linked plates are active. Opening and closing animate on both peers.
- `vent`: hazard jet with `on` and `off` seconds and a phase offset. While on, anything in its footprint loses `vent_air_hit` air once per burst and is pushed back 3 m. A visible rising dust and red warning tell 0.8 s before it fires (readable on a phone).
- `valve`: an Imad-only station (`interact`) that or a plate with `activates: vents_off` for `valve_seconds`. Use a plate version for puzzle B so that Bjorn can run onto it (see below), and keep the `valve` kind out unless needed.
- Add kinds to `entities.json` and procedural props to `proc_props.gd` and `prefabs.json`. Add the numbers to `balance.json`: `vent_on 3.0`, `vent_off 3.0`, `vent_air_hit 12`, `valve_seconds 25`, `plate_radius 1.3`.
- Extend `validate_data.py` to check plate and door links.

Puzzle A, "The Ledge Cache" (near the Dome, east side):
- A caged cache at about (26,0,20) holding 3 apple cores and 2 cans, behind a door. The linked plate sits on top of a ledge (crate stack) at about (16,0,26) whose top is 1.1 m high.
- Bjorn can jump onto it only when solo (solo jump height is `bjorn_jump^2 / (2 * gravity)`, about 1.28 m). Merged jump height is about 0.63 m, so merged players cannot. Imad cannot jump.
- Solution: Bjorn dismounts, jumps on the plate and stays there. Imad crawls to the cache and grabs the loot while the door is open. Add an assertion in `validate_data.py` or an autotest check that ledge height is between the merged and solo jump heights.

Puzzle B, "The Vent Corridor" (west wasteland, past the tower):
- A 30 m corridor along z from 28 to 58 at x=-30, walled by barrels, pipes and crates. Three vents at z=34, 43, 52 with staggered phases. At the far end (z=60) is a plate that sets all vents off for `valve_seconds`; behind it, a cache with 4 apple cores and 3 cardboard.
- Bjorn sprints through the gaps and stands on the end plate. Imad (crawl 2.4 m/s, about 13 s for the corridor) must cross during the vents-off window. Merged crossing is possible but risky, which is fine.
- Plate is not latched: the window starts when Bjorn presses it and runs for `valve_seconds`.

Add both caches to `data/levels/main.json`. Compost now comes from three places, so one failed trip no longer locks the run.

Done when: both puzzles complete on two instances; neither can be completed by one player alone; autotest has a PASS line for the plate/door logic.

---

## P12 · Juice with no assets

1. `core/sfx.gd` (static helper, not an autoload): generate short sounds in code with `AudioStreamWAV` built from computed samples: pickup pop, recycle crunch, craft chime (two rising notes), tower hum (loop, fades in as activation progresses), roach windup growl, plate click, door slide, vent hiss. Play positional sounds with `AudioStreamPlayer3D`, UI sounds with a plain player. Keep volume low and add a master volume key in `balance.json`.
2. Screen shake on roach charge and on tower completion (small, short, camera-only).
3. `CPUParticles3D` bursts, few and cheap: recycle pop, tower activation ring of green sparks, dust on landing and on roach stun.
4. **Visible craft.** At the bench, the Invention Card shows a spinning 3D procedural model of the item for 1 s above the bench: the broomstick built from planks and a bundle, the filter as a canister. Imad visibly holds the selected tool (broomstick on his back or in hand, tongs extended while aiming).
5. Trash shrink-pop on pickup and a floating "+1 plastic" text over the recycler when it finishes.

Done when: the game is no longer silent, nothing allocates per frame in `_process` for audio, and a screenshot of the bench shows the invention preview.

---

## P13 · Onboarding and objectives (replaces the cut prologue)

1. `game/ui/hint_box.gd`: one-line hint at the top-centre under the name tag, event-driven, each hint shown once, fades out when its condition is done. Conditions use `Events`.
2. Objective line (small, top-left under the air bar) that always shows the current goal and updates automatically: collect trash, recycle, make the Filter, activate the tower, craft the broomstick, lure and ambush the roach, go through the gate. Source the text from `data/hints.json`.
3. Role hints, shown to the right player only: Bjorn "Stand next to Imad. He will climb on" / "Jump onto the ledge plate"; Imad "Press Mount near Bjorn" / "Aim with the left stick and press Use tool".
4. A hint arrow or ring in the world pointing to the current objective (the nearest compost cluster, the recycler, the tower), drawn with the style palette, hidden when the target is within 6 m.
5. Add the `hints` section to `validate_data.py`.

Done when: a new player pair can reach the first tower with no spoken help.

---

## P14 · Real 3D models (only after the human has put packs in `assets/models/`)

If `assets/models/` is empty, stop and say so in one line. Otherwise:
1. Run `tools/scan_assets.py`. Choose at most 15 props that fit best: barrel, crate, tyre, pipe, scrap pile, bottle, can, cardboard, plank, a lamp post or two, one industrial tank. Do not replace characters, the roach, stations or the tower.
2. Update only those entries of `data/prefabs.json` with `model`, `scale` (1 unit = 1 m) and `tint_group`. Keep every `fallback`.
3. Make sure `Style.apply` re-tints the imported meshes and that imported collision does not replace the metadata collision.
4. Screenshot the overview and two close-ups. Delete the prefab entry (the procedural fallback takes over) for any model that looks off-style, too detailed, or does not read as a silhouette.
5. Report the triangle count and the draw call count from the Net Meter. If draw calls exceed 150 in the overview, use `MultiMeshInstance3D` for repeated barrels, crates and tyres of the same model.

Done when: at least 8 props are real models, the style still looks uniform, and draw calls are under 150 on the dev overview.

---

## P15 · Content depth for the theme

1. Recipes (JSON plus the small effect code): `mask` (plastic 2, paper 2, air drain x0.6, name "The Breathe-Easy 3000"), `tongs_plus` (metal 3, plastic 2, larger `tongs_radius`, name "The Long Arm of the Law"), `boots` (plastic 3, paper 2, merged speed +15%, name "The Zoomers"). Recipes with effects apply through TeamState `inventory` and `balance.json` multipliers. The craft menu shows owned recipes as "Invented".
2. Add enough trash for these: 2 more plastic and 2 more paper near the Dome, and a second plank cluster. Keep the 5 trash types.
3. A second tower slot at (-40,0,48) is NOT required. Instead, if the first tower is done, the Dome-side restoration should also make 10 to 12 small green sprout props (procedural) appear on the ground near the tower, growing in over 3 s when `Style.restore` runs.
4. Update the objective text in `hints.json` for the new recipes (optional ones are marked "Optional").
5. Radio ending and "To be continued" card stay as they are.

Done when: the three new recipes can be crafted, their effects are visible in the meter or HUD, and the sprouts grow when the tower activates.

---

## P16 · Final polish and release readiness

1. Run `tools/check.py` and fix everything red.
2. Measure at the dev overview and at the pillar: FPS, draw calls, triangles. Reduce anything beyond budget (SPEC §7) with MultiMesh, fewer primitive parts per character, or visibility ranges on far props.
3. Go through partner-lost and restart from every state: lobby, solo, mounting, merged, dismounting, on the perch, during tower hold, during roach charge, end card. Fix state leaks.
4. UI check at 1920x1080 and 2400x1080 through screenshots: buttons never overlap the HUD or hint box.
5. Remove debug prints. Update `docs/RUN.md` with the puzzle map and the Windows firewall line.
6. Do not export for Android.

Done when: `python tools/check.py` is green, the draw call budget is met, and the game plays lobby to end card twice in a row.

---

## Fix prompt (after any test failure)
`Read CLAUDE.md. Bug: <what you saw, which role, what you expected>. Find the cause and fix it with the smallest change. Do not change anything else.`

## Resume prompt (if the usage limit hit mid-prompt)
`Read CLAUDE.md and the "Global rules" section of docs/PROMPTS_2.md. Prompt P<n> in docs/PROMPTS_2.md was interrupted. Run git status and git diff, finish only what is missing for that prompt, then follow the normal ending.`
