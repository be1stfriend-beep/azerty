# PROMPTS_3: Recovery and upgrade round

How to use: type exactly
`Read CLAUDE.md and docs/BRIEF.md, then do ONLY prompt <id> in docs/PROMPTS_3.md.`
(`<id>` is R1, R2, R3, R4, U1, U2 or U3. For P9 to P16 use docs/PROMPTS_2.md with the same first sentence.)
Run `/clear` between prompts. Coordinates and collision layers are as in docs/PROMPTS.md.

## Recommended order
R1, P9, R2, R3, R4, P10, P11, P12, P13, U1, U2, P14, U3, P15, P16
(P9 to P16 come from docs/PROMPTS_2.md. Skip any that docs/STATUS.md from R1 says is already done.)

---

## R1 · Audit and cleanup (no gameplay changes)

1. List every `project.godot`, `export_presets.cfg`, `.godot/` folder and any duplicated `core/`, `game/`, `data/` or `shaders/` folders in the repository, including nested ones. Report them.
2. Keep the project at the repository root. Move any duplicate or nested project to `_duplicate_backup/` (do not delete), add a `.gdignore` file inside it so Godot does not import it, and add it to `.gitignore`. If two copies of a script differ, say which one the root project uses and keep that one.
3. Check `project.godot`: exactly one `run/main_scene` (`res://main.tscn`), the autoloads in the order Style, Data, Events, Net, TeamState, Game with no duplicates, one Android export preset at most.
4. Write `docs/STATUS.md`: for each prompt P1 to P8 (docs/PROMPTS.md) and P9 to P16 (docs/PROMPTS_2.md), mark DONE, PARTIAL or MISSING by checking that its files and functions exist (grep, not guessing). Add a list of stubs, TODOs and dead code you found.
5. Run the Godot headless check and fix every script error.
6. Do not change any gameplay.

Done when: `Get-ChildItem -Recurse -Filter project.godot` outside `_duplicate_backup/` returns exactly one file, STATUS.md exists, and the check is clean.

---

## R2 · Mount soft-lock and the end-to-end run

Bug: after Imad mounted Bjorn the game could not be finished. Find and fix every cause.

1. Review `mount_controller.gd`, `team_state.gd`, `player_base.gd`, `bjorn.gd`, `imad.gd`, touch controls and the camera for these classic causes, and fix any you find:
   - state stuck in MOUNTING or DISMOUNTING (a timer that never fires, a request ignored because `busy` was never cleared)
   - input still locked after mounting, or never re-enabled after dismounting
   - Imad's collision, visibility or cart never restored after dismount; Imad's authority or physics process still disabled
   - the dismount position check failing forever (no free offset) with no fallback
   - the camera or touch buttons not refreshed after a state change (`Events.context_changed` not emitted)
   - guest and host disagreeing on the mount state (one reliable RPC missed, or applied twice)
2. Add a **watchdog** on the host: if MOUNTING or DISMOUNTING lasts more than twice its configured time, force the next valid state and log it. If a dismount has no free offset, place Imad 1.4 m behind Bjorn anyway and ignore collision.
3. Add `--autotest-full` (extends the P9 harness; if P9 is not done, create the minimal harness). A single host process that acts as both characters through the server request functions, and plays the whole game quickly: collect, recycle, craft the Filter, activate the tower, craft the broomstick, mount, reach the perch, make the roach charge into the pillar, apply hits until it flees, gate opens, end card shows. Print PASS or FAIL per step with a reason, exit code 1 on any FAIL.
4. Run it. Any FAIL is a bug to fix in this prompt, with the smallest change.

Done when: `--autotest-full` reaches the end card and prints all PASS, and the watchdog is logged in the Net Meter when it fires.

---

## R3 · Colour restoration in the right place

Bug: the green appears in the wrong space.

1. Reproduce with screenshots: dev level, before pressing T and after `Style.restore(0)`, from three camera positions (overview, near the tower, far from it). Save them in `builds/shots/`. Look at them and describe in 3 lines where the green appears versus where it should (see BRIEF.md "What colour returns means").
2. Check and fix the usual causes:
   - the tower position passed to `Style.set_tower` must be the tower's **global** position, not a local or level-relative one
   - shaders must compare against **world-space** position (`(MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz` computed in `vertex()` and passed as a varying), not view or local space; the ground plane and its scale or offset must not change this
   - radius in metres, distance measured on the XZ plane only
   - `restore_n` per tower goes 0 to 1 and is applied identically on both peers, including a late joiner
   - global uniforms are added before any shader loads and use the exact names the shaders read
3. Blend with `smoothstep(radius, radius - 4.0, distance)` times the restore value. Outside every tower: fully dusty.
4. A thin ring mesh on the ground at the tower radius, using the palette, appearing when the tower is active.
5. Re-take the three screenshots and confirm the green is centred on the tower.

Done when: the green circle is centred on the tower, nowhere else is green, and it looks identical on both instances.

---

## R4 · Bjorn deals small damage; roach with health

1. `balance.json` new keys: `roach_hp 12`, `broom_damage 3`, `kick_damage 1`, `kick_damage_stunned 2`, `kick_range 2.0`, `kick_cooldown 0.7`, `kick_knockback 0.6`. Remove `roach_hits_to_flee`, update every user of it.
2. Generic `take_damage(amount, source_character)` on the roach (the interface future vermin will reuse). Server only.
3. Bjorn's `kick`: his client sends `request_kick()` reliably; the host checks cooldown, distance to the target within `kick_range` and that Bjorn faces it, then applies `kick_damage` (or `kick_damage_stunned` while Stunned). The kick never interrupts a Charge and never stuns. Works solo and merged. The kick animation plays on every peer regardless of a hit.
4. Imad's broom now deals `broom_damage` and still counts only while the roach is Stunned (unchanged rules and reach).
5. Flee triggers when hp reaches 0, not at a hit count. Reset hp when the roach resets.
6. Feedback on every hit: the roach flashes white for 0.1 s, a small hit-pop at the impact point, and a roach health bar above it, visible only while it is awake.
7. Touch buttons: Bjorn has Jump and Kick in both solo and merged states. Update `Events.context_changed` accordingly.
8. Update the autotest to include one kick hit and the new hp flow.

Done when: Bjorn can wear the roach down slowly with kicks while it is stunned or chasing, Imad's broom finishes it faster, and both feel useful.

---

## U1 · Reunion start (replaces the cut prologue and Act 1, cheaply)

1. Start apart: Imad spawns inside the Dome, Bjorn spawns at about (30,0,-6), outside the Dome in the wasteland. Neither sees the other at the start. A short text line per player: Imad "Another day, another bucket." Bjorn "It's fine. Somebody is burning something. That means somebody is there."
2. A thin smoke column (cheap particles or a stack of fading discs) rises from the Dome workshop so Bjorn can navigate to it. Bjorn takes damage from air while outside, so the route should be short (about 35 m) and mostly safe: a trail of 4 or 5 trash piles leading to the Dome.
3. Imad has 2 trash next to him and a hint to recycle them. He cannot reach Bjorn alone (crawl speed), so the meeting is when Bjorn arrives within 6 m: a short camera move toward both and the reunion dialogue from `dialogue.json` (`merge` group), then the mount hint.
4. This replaces the single dialogue line at start. Keep the `start` group lines.
5. The air rules stay as they are; apply them to Bjorn during this walk so it is a tiny survival moment.

Done when: the two players start apart, find each other, the dialogue plays, and the mount tutorial follows.

---

## U2 · Visual identity pass

1. **Dome shell:** a translucent hemisphere (Compatibility safe: simple alpha, a faint fresnel edge from the shader) over the Dome radius, so players see where the safe zone ends.
2. **Miasma:** outside the Dome and active tower radii, a dusty orange haze that gets denser with distance (adjust `Environment` fog density by the local player's safety state, smoothly). Inside: clear.
3. **Landmarks:** the 3 scrap towers get a slow chimney smoke; the Dome gets a few warm light props (no real-time shadows).
4. **Ground detail:** large flat decals made of primitives (tyre tracks, oil stains, rust patches), hand placed in `levels/main.json`, no random scatter.
5. **Character contrast:** screenshot both characters against the dusty ground and the restored ground; fix any that blend in.
6. Keep draw calls under 150 (check the Net Meter).

Done when: the screenshots show a readable safe zone, a visible polluted zone, and characters that pop in both states.

---

## U3 · Industrial zone, Battery and tower 2

1. Gate opens to a small industrial area behind it (z from -36 to -70): about 20 props in rows and piles (tanks, pipes, crates, a conveyor made of primitives) and one scrap tower.
2. New trash item `old_phone` (to electronics, yield 1) with a procedural prop, 5 of them, plus 2 cans, in the industrial area. Add the material `electronics` to `items.json`, the HUD stash and the validator.
3. New recipe `battery` (electronics 2, metal 1, name "The Pocket Sun"). Tower 2 at about (0,0,-60) needs 1 filter and 1 battery; its index is 1 in `Style.set_tower`.
4. Radio ending: after tower 2, the `end` lines from `dialogue.json` and the "To be continued" card.
5. Extend the autotest to cover this route. Keep the roach logic untouched.

Done when: the full game plays through both towers and reaches the end card.
