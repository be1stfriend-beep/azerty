# PROMPTS: Piggyback Planet prototype

How to use: in Claude Code, type exactly
`Read CLAUDE.md, then do ONLY prompt P<n> in docs/PROMPTS.md.`
Run `/clear` between prompts. Test on two instances (`python tools/run_two.py`) before starting the next one.
Each prompt assumes the previous ones are finished and committed.

Coordinates: metres. +X east, +Z south (toward the camera), -Z north, Y up. The camera sits south of the action looking north, so "move up" means -Z.
Collision layers: 1 world, 2 players, 3 enemy, 4 trash.

---

## P1 · Foundation and Data

Create the project skeleton. `core/net.gd` already exists: do not rewrite it.

1. `project.godot` (write it by hand): name "Piggyback Planet", main scene `res://main.tscn`, GL Compatibility renderer, window 1920x1080, stretch mode `canvas_items`, aspect `expand`, landscape orientation, autoloads in this exact order: `Style`, `Data`, `Events`, `Net` (existing file), `TeamState`, `Game`. Add `.gitignore` (`.godot/`, `builds/`, `*.apk`, `*.aab`).
2. `main.tscn`: a single Node root with `main.gd`. For now `main.gd` prints "Data loaded" after `Data` finishes.
3. `core/characters.gd`: `class_name Characters`, `enum Character { BJORN, IMAD }`.
4. `core/input_setup.gd`: static function that registers all actions in code (`move_left/right/up/down`, `aim_left/right/up/down`, `jump`, `kick`, `grab`, `interact`, `use_tool`, `tool_next`, `mount`, `dismount`) with the keyboard map from SPEC Amendments item 3. `Game._ready()` calls it.
5. `core/data.gd` (autoload `Data`): loads every JSON in `data/` at startup (levels from `data/levels/`). Typed getters: `item(id)`, `recipe(id)`, `balance(key)` (returns the value, errors loudly if the key is missing), `prefab(id)`, `entity(kind)`, `dialogue(id)`, `level(name)`. Use `push_error` on missing ids.
6. `core/events.gd` (autoload `Events`): signals only: `state_changed`, `air_changed(value)`, `mount_changed(state)`, `trash_picked(id)`, `item_crafted(id)`, `tower_activated(index)`, `boss_state_changed(state)`, `dialogue_requested(id)`, `context_changed`.
7. Stubs with a `_ready` doing nothing: `core/team_state.gd`, `core/game.gd`, `core/style.gd`.
8. Data files. `data/config.json`: title. `data/balance.json` with exactly these keys: bjorn_walk 5.0, bjorn_jump 7.5, gravity 22.0, imad_crawl 2.4, merged_speed 5.0, merged_jump_mult 0.7, mount_range 2.5, mount_time 0.6, dismount_time 0.4, carry_capacity 8, tongs_radius 1.3, tongs_reach 3.5, broom_radius 2.4, air_max 100, air_drain 2.5, air_refill 25, dome_radius 14, tower_radius 18, tower_hold_seconds 5, sync_hz 20, interp_lerp 12, roach_wake_distance 20, roach_chase_speed 4.5, roach_charge_speed 12, roach_windup 0.7, roach_stun 3.5, roach_hits_to_flee 3, roach_hit_air 15, roach_charge_max 1.4.
   `data/items.json`: 5 trash items (bottle -> plastic yield 1, can -> metal 1, cardboard -> paper 2, apple_core -> compost 1, plank -> wood 1), each with name and prefab id.
   `data/recipes.json`: `filter` (compost 3, paper 2, metal 2, invention name "The Sneeze Filter") and `broomstick` (wood 3, plastic 1, invention name "The Roach Persuader").
   `data/prefabs.json`: one entry per procedural id with `"model": null` and a `tint_group`. Ids: trash_bottle, trash_can, trash_cardboard, trash_apple_core, trash_plank, prop_barrel, prop_crate, prop_tyre, prop_pipe, prop_scrap_tower, pillar, perch, gate, recycler, bench, tower.
   `data/entities.json`: kinds trash, recycler, bench, tower, pillar, perch, gate, prop, each with a prefab rule.
   `data/dialogue.json`: the lines of SPEC §3.10 grouped as `start`, `merge`, `tower`, `boss_done`, `end`.
   `data/levels/main.json`: just `{"name": "main", "entities": []}` for now.
9. `tools/validate_data.py` (parse all JSON, check recipe materials exist in items yields, check level items exist) and `tools/run_two.py` (reads GODOT_BIN, launches instance 1 with `-- --host` at screen position 0,0 size 960x540 and instance 2 with `-- --join 127.0.0.1` at 960,0).

Done when: the check passes, "Data loaded" prints, `python tools/validate_data.py` passes.

---

## P2 · Style and Greybox World

Build the look layer and a procedural world. No players yet.

1. `core/palette.gd`: constants from SPEC §4.4.
2. `shaders/world_style.gdshader` (spatial, works in Compatibility): uniform `tint` and optional texture; 3-step cel shading in `light()`; thin rim light; global uniforms `tower_0`..`tower_3` (vec4: world xyz, radius w) and `restore_0`..`restore_3` (float). Inside a tower's radius, blend by its restore value from a dusty look (desaturated, warm, darker) to a lush look (saturated, brighter). Outside every tower: fully dusty.
3. `shaders/ground.gdshader`: same restoration inputs, dust colour to grass colour, with subtle large-scale noise bands so the ground is not flat.
4. `shaders/vignette.gdshader` and a CanvasLayer in `Game` that adds a soft vignette and a faint warm haze. Nothing else (no bloom).
5. `core/style.gd` (autoload `Style`, first in order): in `_ready` call `RenderingServer.global_shader_parameter_add` for all 8 globals (before any shader loads). Functions: `material(tint_group: String) -> ShaderMaterial` (cached per group), `apply(node: Node)` (every MeshInstance3D gets the style material for its `tint_group` metadata), `set_tower(index, position, radius)`, `restore(index, seconds := 3.0)` (tween restore value 0 to 1 on all peers).
6. `game/world/proc_props.gd`: static `build(prefab_id) -> Node3D` for every id in prefabs.json, from primitives only, chunky and readable, with `metadata/collision` (shape and size) where the prop should block movement. Oversize the trash for readability: bottle 0.8 m tall, can 0.5, cardboard box 0.9, apple core 0.55, plank 1.6 long. Pillar: 2 m wide, 5 m tall, striped with two tint bands. Perch: stack of crates 2.5 m tall, 3 m wide. Gate: two posts and a slab, 6 m wide. Recycler: boxy machine with hopper and chute. Bench: table with vice. Tower: tall base with a fan on top.
7. `core/util/entity_factory.gd`: `spawn(kind, id, params) -> Node3D`: if the prefab has a model path that exists, load it, apply scale, style it; otherwise `the procedural builder`. Add a StaticBody3D with the collision metadata on layer 1. Node name equals the id.
8. `core/util/level_loader.gd`: reads `Data.level(name)`; creates `World` > `Ground` (big plane with ground.gdshader) > `Entities`; spawns each entity with deterministic id `<kind>_<index>`; a ring mesh marks the Dome edge.
9. `data/levels/main.json`, hand-authored layout (no uniform random scatter): Dome radius 14 at origin with recycler at (-6,0,-4) and bench at (6,0,-4); spawn markers bjorn (-3,0,4) and imad (3,0,4); tower at (-22,0,16); pillar at (0,0,36); perch at (5,0,36); gate at (0,0,-34); roach spawn marker (0,0,52). Trash: 3 bottles, 4 cans, 2 cardboard, 4 apple cores (all at z > 22), 4 planks, placed in 6 hand-made clusters between the Dome and the wasteland. About 30 props (barrels, crates, tyres, pipes) in rows and piles that suggest a path to the pillar, plus 3 scrap towers as landmarks.
10. `main.gd`: if the command line has `--dev-level`, load the level with a fixed camera at (0,24,26) looking at (0,0,10) and a key `T` that calls `Style.set_tower(0, tower_position, 18)` then `Style.restore(0)`.

Done when: running with `-- --dev-level` shows the styled world, no default grey materials, and pressing T brings colour back around the tower.

---

## P3 · Networking and Lobby

`core/net.gd` is the base and already works. Build the lobby and match start around it.

1. `game/ui/lobby.gd` (all UI built in code, Control-based): big buttons at least 100 px tall, font size 40. Buttons "Host as Bjorn" and "Host as Imad"; an IP field plus "Join" button, prefilled from `user://last_ip.cfg` (ConfigFile); a label with this device's IP from `Net.local_ip()` while hosting; a status label ("Waiting for partner...", "Connected", errors from `join_failed`). Shown by `main.gd` at start (unless `--dev-level`). Quit button on PC only.
2. `Game.start_match()` (host only, called on `Net.connection_established`): sends a reliable RPC to the guest, then both peers load the level via the LevelLoader and hide the lobby. If the command line used `--host`/`--join`, the lobby is skipped and the same flow runs.
3. `Game.return_to_lobby()`: frees the world, calls `Net.leave()`, shows the lobby. Connect `Net.partner_lost` to a full-screen overlay "Partner lost" with a "Back to lobby" button.
4. `game/ui/net_meter.gd`: CanvasLayer toggled by F3 and a small corner button. Shows role, ping from `Net.rtt_ms()`, loss from `Net.loss_percent()`, and a free line the other systems can set (`NetMeter.set_line(key, text)`). Updated twice per second. If `peer.host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA)` and `HOST_TOTAL_RECEIVED_DATA` are usable, also show up/down kbps; otherwise skip them.

Done when: `python tools/run_two.py` brings up two windows that both load the same level; closing one shows "Partner lost" on the other; the meter shows a ping.

---

## P4 · Players, Camera and Touch

1. `game/actors/character_builder.gd`: builds both characters from primitives with `Style` applied (character tint groups from the palette), chunky and wobbly, head about one third of body height.
   Bjorn (1.9 m, tall and thin): cyan parka torso, long legs, big boots, white beanie with red pompom, sleeves ending in rounded stumps with no hands, wide dopey eyes (white spheres with black pupils), a `Saddle` Marker3D at his upper back.
   Imad (about 1.1 m seated, short and wide): solid torso with cobalt vest, thick arms with round hands, orange goggles pushed up on dark curly hair, standing on a scrap crawler cart (box base, four small wheels).
   Procedural wobble: `update_wobble(delta, velocity, grounded)` tilts the body against acceleration and squashes on landing. A dark blob quad under each character as the shadow (no real-time shadows).
2. `game/actors/player_base.gd` (CharacterBody3D, layer 2, collides with layer 1), `bjorn.gd`, `imad.gd`. Node names `bjorn` and `imad`. The owner is `Net.peer_for_character(role)`; call `set_multiplayer_authority(owner)`. Only the authority reads input and moves. Bjorn: walk `bjorn_walk`, jump with gravity, kick plays an animation only. Imad: crawls at `imad_crawl`, no jump. Facing turns toward movement.
3. Sync: the authority sends position, y rotation, velocity and state with an unreliable_ordered RPC at `sync_hz`. Remotes lerp toward the latest value with `interp_lerp`, and snap if farther than 6 m.
4. `Game.start_match` spawns both players at the spawn markers (same code on both peers).
5. `game/camera/follow_camera.gd`: fixed yaw, pitch -55 degrees, follows the midpoint of both players, zooms out to keep both in frame up to a 30 m leash; beyond that it follows the local player only. Smooth with lerp.
6. `game/ui/touch_controls.gd`: shown if `DisplayServer.is_touchscreen_available()` or the arg `--touch`. Left virtual joystick (radius 120 px) that presses `move_*` actions with analog strength. Right side: two contextual buttons, minimum 150 px, with text labels. Bjorn: Jump and Kick. Imad: Grab and Interact. Proper multi-touch (joystick and button at the same time). Listens to `Events.context_changed` so P5 can swap the buttons.
7. Movement input is camera-fixed: up is -Z.

Done when: two windows each control their own character, the partner moves smoothly, Bjorn jumps, props block movement, and the characters read clearly against the ground.

---

## P5 · Mount, Rider Aim and Tongs

1. `core/team_state.gd`: host-owned `state` Dictionary: `carried` (array of item ids), `stash` (dict), `tools` (["tongs"]), `current_tool`, `inventory` (dict of crafted items), `picked` (array of trash ids), `towers` (array), `mount` ("SOLO"), `air`. The host mutates it through `request_*` functions (pattern of SPEC §6.5) and after every change calls one reliable RPC that sends the whole dictionary to the guest, then emits `Events.state_changed`. Clients never modify it.
2. `core/net/mount_controller.gd` (host logic, states SOLO, MOUNTING, MERGED, DISMOUNTING per SPEC §6.3): Imad's `request_mount` is accepted if SOLO and the distance is within `mount_range`; MOUNTING lasts `mount_time` then MERGED; either player may `request_dismount` while MERGED. Duplicate requests are ignored. The dismount position tries 8 offsets 1.4 m around Bjorn and uses a physics sphere query against layer 1; if none is free the request fails with a short message. Mount state replicates via TeamState. If `Net.partner_lost` fires while merged, force SOLO.
3. Merged behaviour (identical code on both peers, driven by `TeamState.state.mount`): Bjorn's client is the authority for the body, moves at `merged_speed`, jumps at `bjorn_jump * merged_jump_mult`. Imad's node is placed at Bjorn's `Saddle` every frame, copies Bjorn's rotation, hides his cart, has collision disabled and sends no movement. The HUD name tag text (set via `NetMeter.set_line` for now) shows BJIMAD.
4. Rider aim: while merged, Imad's left stick feeds `aim_*` instead of movement. His client sends the aim vector with an unreliable RPC at `sync_hz`. All peers draw a flat ring reticle on the ground at `body_position + aim * tongs_reach`. When solo, the reticle is 1.2 m in front of Imad. Reuse the same ring with `Style`.
5. Tools: `use_tool` (and `grab` when solo) sends `request_use_tool(world_position)` reliably to the host. For the tongs the host picks the nearest unpicked trash within `tongs_radius` of that point if `carried` is below `carry_capacity`, adds it to `carried`, and adds the id to `picked`. Clients hide picked trash with a small shrink-pop. `tool_next` cycles `tools`.
6. Contextual touch buttons through `Events.context_changed`: Bjorn merged: Jump, Dismount. Imad merged: Use tool, Next tool, Dismount. Solo Imad: Grab, Interact, Mount (shown when Bjorn is in range). Solo Bjorn: Jump, Kick.

Done when: 20 mount and dismount cycles in a row with no desync (log the count to the meter), a blocked dismount behaves, and Imad can aim and pick up trash from Bjorn's back while Bjorn walks.

---

## P6 · Economy, Air and Tower

1. Stations as `Interactable` nodes (a small base in `core/util/interactable.gd`: `kind`, `range`, `interact(player)`), spawned by the factory. `interact` from either Imad solo or the rider counts when the body is within range.
2. Recycler: `interact` sends everything in `carried` to the stash as materials using each item's yield (`request_recycle`). Short pop animation and chute effect.
3. Bench: `interact` opens a code-built craft menu (large buttons, Control-based): each recipe shows its cost, green if affordable, and an "Invent" button. `request_craft(recipe_id)` on the host deducts materials and adds `filter` to `inventory` or `broomstick` to `tools`. Then an Invention Card shows on both screens for 2.5 s: "INVENTED: <invention_name>".
4. Air: the host ticks `air` every frame. Safe inside the Dome and inside active tower radii; drains at `air_drain` elsewhere (any player outside counts), refills at `air_refill` inside. At 0 both players respawn at the spawn markers, mount forced to SOLO, `carried` cleared, stash kept, a message "Out of air. Back to the Dome."
5. Tower: Imad holds `interact` within 3 m for `tower_hold_seconds`. The host tracks the hold (`request_hold(station_id, held)`), requires 1 `filter` in `inventory`, shows a progress bar on both screens, and cancels if released. On completion: consume the filter, add the tower index to `towers`, call `Style.set_tower(i, position, tower_radius)` and `Style.restore(i)` on both peers, and extend the safe area.
6. HUD (`game/ui/hud.gd`, code-built, one font, palette colours, no emoji): air bar top-left; carried count "n/8" and current tool bottom-centre; stash counts top-right as coloured squares with numbers; name tag top-centre (BJIMAD when merged).

Done when: collect, recycle, craft Filter, activate the tower, and the colour returns on both screens; running out of air respawns both players.

---

## P7 · Cockroach Boss

1. `game/actors/cockroach.gd`, server-only logic on the host, states Idle, Chase, WindUp, Charge, Stunned, Flee (use a small `core/util/state_machine.gd`). It spawns at the roach spawn marker and sleeps until a player is within `roach_wake_distance`.
2. Chase: moves toward the nearest valid target (not inside the Dome or any active tower radius, not standing on the perch) at `roach_chase_speed`. At 7 m it enters WindUp for `roach_windup`: it rears up, eyes turn red, and it faces the target (readable on any screen). At the end it locks the direction and Charges in a straight line at `roach_charge_speed` for at most `roach_charge_max` seconds.
3. Charge ends when it hits the pillar (distance check against the pillar's collider) which makes it Stunned for `roach_stun`; when it hits a player they lose `roach_hit_air` air and are knocked back 4 m, then it returns to Chase; if it hits nothing it returns to Chase.
4. Perch: when merged and Bjorn's body is within 3 m of the perch, Imad's dismount puts him on top of the perch (raised 2.5 m, flagged on_perch). While on the perch he cannot be targeted. He can remount by interacting when Bjorn stands within 3 m.
5. Broom hit: with the `broomstick` tool selected, `use_tool` from Imad (aim point within `broom_radius` of the roach, or within 3.5 m of the roach while on the perch) counts only while Stunned. Each hit shakes the roach. After `roach_hits_to_flee` hits it enters Flee: runs north out of view, then is removed. The gate then opens (slides down) on all peers and a message appears.
6. Replication: the host sends roach position, rotation, state and the gate state with an unreliable_ordered RPC at `sync_hz` (state changes reliable). Clients only render and play the tells. Build the roach from primitives (dark shell `#3A2A3F`, green belly, red eyes, six legs animated by sine waves, antennae).
7. If both players are knocked out, the roach resets to Idle at its spawn marker with no hits.

Done when: the lure-and-ambush works with two real players: Bjorn lures, Imad is dropped on the perch, the roach charges into the pillar, Imad broom-hits three times, the roach flees and the gate opens. Test it once with 100 ms of added latency if the Windows tool for it is available; otherwise note it.

---

## P8 · Story and Finish

1. `game/ui/dialogue_box.gd`: bottom panel with speaker name and text, advances by tap or after 3.5 s. Lines from `dialogue.json`, triggered by `Events.dialogue_requested`.
2. Triggers: match start (`start`), first time MERGED (`merge`), first tower activation (`tower`), roach flees (`boss_done`), then 6 seconds later the `end` lines, then a "To be continued" end card with a Restart button (host restarts the match for both).
3. Partner-lost and restart paths work from every state.
4. UI scaling: all UI anchors and sizes tested at 1920x1080 and 2400x1080; touch buttons never overlap the HUD.
5. Remove debug prints. Write `docs/RUN.md` (10 lines): how to run two instances, how to join over wifi (host shows its IP), the Windows firewall command `New-NetFirewallRule -DisplayName "Piggyback" -Direction Inbound -Protocol UDP -LocalPort 7777 -Action Allow`, and the F3 meter.
6. Do not do the Android export. The human does it in the editor.

Done when: the game can be played from the lobby to the end card twice in a row without restarting the app.

---

## Fix prompt (use after any test failure)

`Read CLAUDE.md. Bug: <what you saw, which role, what you expected>. Find the cause and fix it with the smallest change. Do not change anything else.`

## Resume prompt (if the usage limit hit mid-prompt)

`Read CLAUDE.md. Prompt P<n> in docs/PROMPTS.md was interrupted. Run git status and git diff, finish only what is missing for that prompt, then follow the normal ending.`
