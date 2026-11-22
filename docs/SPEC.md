# PIGGYBACK PLANET: Specification (v2, 3D)

> Godot 4.7.2 · GDScript · Compatibility renderer · Android landscape · 3D · 2-player online co-op · English
> Working title lives in `data/config.json`. Alternatives: *Scrap Happy*, *Two Heads, One Bin*.
> If code and this file disagree, one is a bug. Fix both in the same commit.

---

## AMENDMENTS (these override anything below)

1. **Networking is a listen server.** The host phone/PC is the server and also plays. `core/net.gd` is the base. There is no dedicated server, no VPS, no room code, no WebSocket in this build. Join by LAN IP on the same wifi or hotspot, UDP port 7777.
2. **Sync uses plain RPCs, not MultiplayerSynchronizer.** Owners send position with an unreliable ordered RPC at 20 Hz and remotes interpolate. Shared state (`TeamState`) is a Dictionary owned by the host and pushed to the client with one reliable RPC on every change.
3. **Input actions are registered in code** (`core/input_setup.gd`), not in project.godot. Keyboard: WASD move, arrows aim, Space jump, J kick, G grab, E interact, F use_tool, R tool_next, M mount, N dismount.
4. **Everything works with procedural props first.** Downloaded models are an optional upgrade through `prefabs.json`.
5. **Scope is the 7-hour cut** in `BUILD_PLAN_7H.md` §1. Audio is cut. Tools are Python scripts (Windows).
6. **The prompt sequence is `docs/PROMPTS.md`.** It replaces the session list in BUILD_PLAN_7H.

---

## 0. Pitch

Theme: **nothing gets thrown away, everything gets invented.**

Two survivors, **Bjorn** and **Imad**, each assumed the other was gone. They find each other in a poisoned junk world. Alone, each is capable but limited. Together, one carries the other. They turn trash into inventions and use them to purify the land, one tower at a time, until colour comes back.

**The product is "one body, two phones."** When merged, one player steers the body and the other operates the tools. Neither can win alone. It runs over a real network (the event is about 5G SA in Tunisia). Everything else supports this.

**Core loop:** scavenge trash → recycle → invent (craft) → activate a purification tower → colour returns.

### Pillars
1. **Interdependence.** Every challenge needs both players.
2. **Readable cooperation.** Each player always knows what the partner is doing and what they can do.
3. **Everything is invented.** Each craft is a small "invention" moment. The world is built from junk and visibly heals.
4. **Survival with a light touch, no pity.** Humour comes from the friendship, never from their bodies. Nobody is rescued, fixed or admired for overcoming anything. They are capable adults whose abilities complement each other.

---

## 1. Locked decisions

| # | Decision |
|---|---|
| D1 | Godot **4.7.2**, GDScript, static typing |
| D2 | **Compatibility** renderer (widest Android support). All stylisation is in our own shaders, not in renderer-specific effects |
| D3 | **True 3D**, flat ground plane (no terrain heightmap). Height comes only from props. Keeps collision, AI and netcode simple |
| D4 | Landscape only. Fixed high third-person camera with a follow leash |
| D5 | **Online only**, exactly 2 players, one phone each |
| D6 | **Server-authoritative**, Godot high-level multiplayer + ENet. Must run as a **dedicated headless server** (primary on 5G) and as listen-server (LAN/dev) with the same code |
| D7 | Team-wide shared state: one air meter, one stash, one tool set |
| D8 | Roles fixed: **Bjorn carries, Imad rides** |
| D9 | **Data-driven**: items, recipes, trash, prefabs, levels, balance, dialogue in JSON, loaded by one `Data` autoload |
| D10 | Game logic never assumes the host is a character |
| D11 | Characters and the cockroach are **built from primitives in code** with procedural spring animation. Environment props come from **CC0 asset packs**. No rigged imports |
| D12 | One style layer (§4.3) wraps every mesh. Nothing renders with its original material |

---

## 2. Characters and tone

Codenames **No Hands** (Bjorn) and **No Legs** (Imad) are internal. Never in UI, dialogue or code. Code uses `bjorn`, `imad`, `carrier`, `rider`.

| | **Bjorn** | **Imad** |
|---|---|---|
| Origin | Scandinavian | Tunisian |
| Look | Tall, lanky, pale. **Not a Viking**: no beard, braids, fur or horns. Oversized cyan rain parka, white bobble beanie with a red pompom, huge boots. Sleeves end where hands would be | Stocky, strong shoulders, short dark curly hair, orange welding goggles pushed up, cream overalls with a cobalt tool vest. Rides a self-invented scrap crawler cart when solo |
| Voice | Endlessly calm. Says "it's fine" while everything is on fire. Understated, polite, accidentally funny | Fast, sarcastic, always inventing. Reads the instructions. Names everything |
| Moves | Walk, run, jump, kick | Crawler cart (slow), tongs reach |
| Interacts | Kicks objects and enemies. Cannot grab or use tools | Tongs, crafting, recycling, broom |
| Needs partner for | Holding things, crafting | Speed, jumping, high places |

Silhouette rule: **Bjorn = tall and thin, Imad = short and wide.** Readable at 100 px.
Scale: Bjorn 1.9 m, Imad 1.1 m seated. Heads are about 1/3 of body height (Totally-Accurate-Battle-Simulator-style chunky, wobbly, dopey faces).

**Fusion name (HUD tag when merged):** BJIMAD. *Imad: "That's a sneeze, not a name." Bjorn: "It's fine. It's a good sneeze."*

Tone: Wall-E warmth with TABS silliness. The massacre is implied, never shown.

---

## 3. Gameplay

### 3.1 Controls (touch, landscape)
Left thumb: virtual joystick. Right thumb: action buttons. Touch feeds the same input actions as keyboard so everything is testable on PC. Touch targets at least 96 px at 1080p.

Input actions (defined in `project.godot`): `move_left/right/up/down`, `jump`, `kick`, `grab`, `interact`, `use_tool`, `tool_next`, `mount`, `dismount`, `aim_left/right/up/down`.

| Context | Left thumb | Right thumb |
|---|---|---|
| Bjorn solo | Move | Jump, Kick |
| Imad solo | Crawl | Grab, Interact |
| Merged, Bjorn's phone | Move | Jump, Dismount |
| Merged, Imad's phone | **Aim** | Use tool, Next tool, Dismount, Craft (near bench) |

### 3.2 World
- **The Dome:** safe, clean air, contains the **Recycler** and the **Bench**. Enemies cannot enter.
- **The Wasteland:** one open zone, desaturated dusty orange haze. Air drains while anyone is outside a clean radius.
- **Industrial block:** a second area behind a gate that the boss guards (P1 content, simple).

### 3.3 Air (team-wide)
Start 100. Drain 2.5/s outside, 1.5/s with Mask, refill 25/s in the Dome. At 0 both players are knocked out and respawn at the Dome. Carried (unrecycled) trash is lost. Stash is kept. Numbers live in `data/balance.json`.

### 3.4 Trash, recycling
Imad picks up trash with tongs (range upgradeable). Carry capacity 8. Bjorn can kick **heavy trash** (tyres, crates; P2) into the Recycler intake.

Trash (8 types) → material (6 materials), each with a process time:

| Trash | Material | Where |
|---|---|---|
| Bottle, Bag | plastic | everywhere |
| Can, Scrap | metal | everywhere, more in industrial |
| Cardboard | paper | Dome area, wasteland |
| Apple core | compost | wasteland only |
| Old phone | electronics | industrial only |
| Plank | wood | Dome area, wasteland |

### 3.5 Inventions (crafting at the Bench, Imad)
Each craft plays a short **Invention card**: a one-line funny name ("The Sneeze Filter") and a 1-second spin of the object. Names live in `recipes.json`.

| Item | Cost | Effect | Priority |
|---|---|---|---|
| Tongs+ | metal 3, plastic 2 | larger pickup radius | P0 |
| Mask | plastic 2, paper 2 | slower air drain | P0 |
| Broomstick | wood 3, plastic 1 | melee, boss fight | P0 |
| Filter | compost 3, paper 2, metal 2 | starts a tower | P0 |
| Battery | electronics 2, metal 1 | needed with Filter for tower 2 | P1 |
| Boots | plastic 3, paper 2 | +15% speed merged | P2 |

### 3.6 Towers
Needs a Filter (plus a Battery for tower 2). Imad holds `interact` ~5 s while Bjorn defends. Result: no air drain in radius, **colour returns** (§4.3 restoration), area becomes safe. Two towers in scope.

### 3.7 Cockroach (server-side state machine)
`Idle → Chase → WindUp → Charge → Stunned → Flee`

| State | Behaviour |
|---|---|
| Chase | Targets nearest player not on a perch or in the Dome |
| WindUp | 0.5 s tell (rear up, red eyes, sound) |
| Charge | Fast, straight line. Hits a **pillar**: stunned. Hits a player: knockback and air loss |
| Stunned | ~3 s, the only time broom hits count |
| Flee | After 3 hits it retreats and the industrial gate opens |

### 3.8 Merged form
Movement from Bjorn's phone, tools from Imad's. Speed equals Bjorn's walk. Jump lower than solo. Either can dismount if space is free. Imad initiates mount within range.

### 3.9 Story flow (about 10 minutes of play)
- **Prologue:** 4 skippable still cards (text on painted-colour backgrounds, no generated text in images): lively community at dusk; smoke over it (implied only); empty settlement; two separate figures, "Some time later…".
- **Act 1 (2 to 3 min):** both play at once in separate areas of the same level, each thinking they are alone. Bjorn: finds boots, jumps a crate, kicks a can, follows chimney smoke. Imad: crawls, grabs 2 trash, recycles, settles in. Ends when Bjorn reaches the workshop.
- **Act 2, the merge:** reunion cutscene (§3.10), merged tutorial, make Mask, first excursion, scripted cockroach chase back to the Dome, craft Filter (needs compost from wasteland), activate Tower 1.
- **Act 3, fight back:** craft Broomstick. **Lure-and-ambush:** Bjorn runs circles to lure it; Imad is dropped on a **perch** by the pillar; cockroach charges, hits the pillar, is stunned; Imad whacks it three times. Gate opens, electronics appear, Battery, Tower 2, radio ending, end of build.

### 3.10 Key dialogue (edit freely, keep voices)
> **Imad:** Bjorn?! You're alive!
> **Bjorn:** Hi. Yes. I was just passing by. For three weeks.
> **Imad:** I've been talking to a bucket. The bucket had better answers.
> **Imad:** Listen. You've got the legs, I've got the hands. Get me on your back.
> **Bjorn:** I'd prefer to walk next to you. In a straight line. Forever.
> **Imad:** Bjorn.
> **Bjorn:** …Climb.
>
> *Merged:* **Bjorn:** Together we are… Bjimad. **Imad:** That's a sneeze, not a name. **Bjorn:** It's fine. It's a good sneeze.
>
> **Radio:** "…survivors… if anyone hears this… the rail yard still has power. Bring filters…"
> **Imad:** There are *more* of us? **Bjorn:** Great. I'll pack snacks.

---

## 4. Art direction (anti-slop)

### 4.1 References
**Wall-E:** warm dusty haze, rusty industrial scale, towers of compacted trash, a tiny hopeful green sprout, soft backlight, readable silhouettes.
**Totally Accurate Battle Simulator:** chunky simple bodies, big dopey faces, bold flat colours, wobbly secondary motion.
Combined: **warm, dusty, rusty world; cool, saturated, chunky characters that pop; colour literally returns when you heal the land.**

### 4.2 Hard rules
1. **One palette** (§4.4) stored in `assets/style/palette.tres`. Nothing outside it.
2. **One shader family.** 3-step cel ramp, rim light, restoration desaturation. No PBR, no default materials.
3. **No emoji, no stock icons.** UI uses one font, one colour set, and simple shapes made in code.
4. **No random scatter.** Levels are authored in JSON. Trash and props are placed by hand-written clusters (landmarks, rows, piles), never uniform noise.
5. **Scale consistency.** 1 unit = 1 metre. Every prefab has a `scale` and `tint_group` in `prefabs.json`.
6. **Silhouette first.** Props must read in one colour. Reject packs that look like generic low-poly stock.
7. **Contrast check.** Characters must have a luminance contrast against the ground in both polluted and restored states.
8. **Limited post-processing:** one vignette and one warm haze. No bloom, no everything-glows.
9. **Wobble, not ragdoll.** Squash, stretch and spring tilt in code. No physics ragdolls (network cost).
10. Anything off-style is removed from `prefabs.json`, not patched.

### 4.3 Style layer (the single most important system)
- `world_style.gdshader`: samples the model's original albedo texture, quantises lighting to 3 steps from a palette ramp, adds a thin rim, and multiplies by a haze tint by distance.
- **Restoration:** global shader uniforms `tower_0..tower_3` (vec4: xyz position, w radius) and `restore_t_0..3` (0..1). Fragment saturation and tint blend from dusty to lush inside a tower's radius. Activating a tower animates `restore_t_n` over 3 s. **No new art is needed for the colour return.**
- `StyleApplier` (autoload service): `apply(node)` walks all `MeshInstance3D`, replaces materials with `ShaderMaterial` instances from the shared `world_style` using the original texture, grouped by `tint_group`. Called by the entity factory for every spawned prefab and by the character builder.
- Characters use a `character_style.gdshader` variant (no restoration, stronger rim, face decals drawn procedurally).
- Blob shadows (a dark quad under each entity), no real-time shadows on phones. Optional single shadow-cast directional light only on PC.

### 4.4 Palette (proposal; one file to retune)
| Role | Hex |
|---|---|
| Haze sky | `#D9A066` |
| Dust ground | `#B5834F` |
| Rust | `#8A4B2A` |
| Soot | `#3A3330` |
| Concrete | `#8F877A` |
| Bone white | `#F3EBDD` |
| Restored grass | `#8BC34A` |
| Restored sky | `#7EC8E3` |
| Restored teal | `#2FA39A` |
| Bjorn parka | `#35B6D6` |
| Bjorn pompom | `#D8432E` |
| Imad vest | `#2B4C9B` |
| Imad goggles | `#F08A24` |
| Skin A | `#F1D3BE` |
| Skin B | `#B07A55` |
| Roach shell | `#3A2A3F` |
| Roach eyes / danger | `#E5342A` |

### 4.5 Asset sourcing
CC0 only. Kenney (Survival Kit, City Kit Industrial, Nature Kit, Space Kit), Quaternius, Poly Pizza. Search terms: *trash, junk, barrel, tyre, crate, container, pipe, tank, pylon, rubble*.
Process: Editor human downloads, keeps only what matches the style, drops into `assets/models/<pack>/`. `tools/scan_assets.py` creates `prefabs.json` skeleton entries. Claude Code never opens binaries.
**Fallback for any missing model:** a primitive "procedural prop" recipe in `data/procedural_props.json` (lathe bottle, cylinder can, box cardboard). The old web prototype's `waste.js` models are the reference for these shapes. A missing model must never block a step.

---

## 5. Architecture (scalable by data)

### 5.1 Folder structure
```
project.godot
CLAUDE.md
docs/            SPEC.md  BUILD_PLAN.md
data/            config, balance, items, recipes, prefabs, entities, procedural_props,
                 characters, dialogue, levels/*.json
core/            autoloads: net.gd data.gd events.gd team_state.gd game.gd style.gd
core/net/        transport_*.gd  mount_controller.gd  net_meter.gd
core/util/       state_machine.gd  interactable.gd  entity_factory.gd  level_loader.gd
game/actors/     player_base.gd bjorn.gd imad.gd character_builder.gd cockroach.gd
game/world/      station.gd recycler.gd bench.gd tower.gd trash.gd pillar.gd perch.gd gate.gd
game/ui/         hud.gd touch_controls.gd lobby.gd dialogue_box.gd invention_card.gd
game/camera/     follow_camera.gd
assets/          models/ style/ audio/ fonts/
tools/           scan_assets.py  validate_data.py  run_two.sh  export_server.sh
builds/          git-ignored
```

### 5.2 Autoloads (keep to six)
| Name | Job |
|---|---|
| `Data` | Loads and validates all JSON, typed getters (`Data.item(id)`) |
| `Events` | Signals only. No logic |
| `Net` | Transport, roles, lobby, disconnect, net meter |
| `TeamState` | Replicated shared state: air, stash, carried, mount state, tower flags |
| `Game` | Act progression, level loading, cutscenes, pause |
| `Style` | StyleApplier, global shader uniforms, restoration animation |

### 5.3 Building blocks
- **`Interactable`** component: `kind`, `prompt`, `range`, `allowed_roles`, `interact(player)`. Everything the player can use inherits it.
- **`Station`** base (extends `Interactable`): Recycler, Bench and Tower extend it. A new station is a subclass plus an entry in `entities.json`.
- **`StateMachine`** generic enum/`match` helper used by the cockroach and the mount controller. A new enemy is a new states list plus `entities.json`.
- **`EntityFactory`**: `spawn(kind, id, params)` maps `entities.json` kind to scene or script and prefab model, applies the style layer.
- **`LevelLoader`**: reads `data/levels/<name>.json` and spawns entities with deterministic ids (`kind_index`) so both peers build identical worlds without spawn RPCs.

### 5.4 How to add anything (the scalability contract)
| To add… | Do this |
|---|---|
| A new trash type | Model into `assets/`, one entry in `items.json`, a process in `recipes.json`. Zero code |
| A new material or recipe | One JSON entry |
| A new prop or building | Model in `assets/`, one entry in `prefabs.json`, place it in a level JSON |
| A new station | Subclass `Station`, one entry in `entities.json` |
| A new enemy | Subclass using `StateMachine`, one entry in `entities.json` |
| A new zone or level | New `data/levels/*.json` |
| A tower | Level JSON entry with `kind: "tower"` and its radius. The shader handles colour |

### 5.5 Data schemas (examples; `validate_data.py` enforces them)
```json
// items.json
{"bottle": {"name": "Plastic Bottle", "material": "plastic", "process_time": 2.0, "prefab": "trash_bottle", "weight": 1}}
// recipes.json
{"mask": {"name": "Mask", "cost": {"plastic": 2, "paper": 2}, "effect": {"air_drain_mult": 0.6},
          "invention_name": "The Breathe-Easy 3000", "priority": "P0"}}
// prefabs.json
{"trash_bottle": {"model": "res://assets/models/kenney_survival/bottle.glb", "scale": 1.0,
                  "tint_group": "plastic", "collision": "none", "fallback": "proc_bottle"}}
// entities.json
{"recycler": {"script": "res://game/world/recycler.gd", "prefab": "station_recycler"}}
// levels/main.json entity
{"kind": "trash", "item": "bottle", "pos": [4.0, 0, -12.5], "rot": 35}
```

---

## 6. Networking

### 6.1 Topology
- Godot high-level multiplayer with `ENetMultiplayerPeer`, exactly two clients.
- **Primary: dedicated headless server** on a VPS with a public IP (`godot --headless -- --server --port 7777`). Phones on 5G SA are likely behind carrier NAT, so a phone cannot be the host. Both phones connect as clients.
- **Dev/LAN: listen server.** The host is the server and also plays. Same code path (`multiplayer.is_server()`).
- **Transport abstraction:** `NetTransport` interface with `ENetTransport` (build first) and `WebSocketTransport` (P1 fallback if the operator blocks UDP). Game code never touches the peer type.
- Lobby: join by server address plus a 4-letter room code. Server assigns roles (first to choose wins the pick; the other gets the remaining role).
- **Net Meter (P0, also a demo feature):** ping, round-trip, loss, up/down kbps, from `ENetPacketPeer.get_statistic`. A toggled in-game overlay and a final "your session" stats card for the jury. This makes the 5G SA story visible.

### 6.2 Authority
| What | Authority |
|---|---|
| Solo character transform | **The owning client** |
| Merged body transform | **Bjorn's client** |
| Rider (Imad mounted) | **Nobody.** Computed locally at the Saddle marker |
| Rider aim vector | Imad's client, unreliable RPC ~20 Hz |
| Mount/dismount state | **Server** |
| Pickups, recycler, crafting, stash, air, towers | **Server** |
| Cockroach and all AI | **Server only**, clients render |
| Thrown/dropped dynamic objects | Server via `MultiplayerSpawner` |
| Static level entities | Deterministic ids, state in `TeamState` (no spawn RPCs) |

### 6.3 Mount state machine (server-owned)
```
SOLO ──(Imad: request_mount, in range, neither busy)──▶ MOUNTING (0.6 s, inputs locked)
MOUNTING ──▶ MERGED
MERGED ──(either: request_dismount, space free)──▶ DISMOUNTING (0.4 s)
DISMOUNTING ──▶ SOLO
```
Edge cases: simultaneous dismount (first wins); blocked dismount (server picks nearest free offset); disconnect while merged (force dismount, pause, "Partner lost"); air 0 (both respawn solo at Dome); mount during a charge is allowed.

### 6.4 Sync
Physics 60 Hz. Position via `MultiplayerSynchronizer` at 0.05 s. Remote interpolation with a ~100 ms buffer. Reliable RPCs: mount, pickup, craft, tower, tool swap. Unreliable: aim. Player nodes named by peer id, `set_multiplayer_authority()` in `_enter_tree()`.

### 6.5 Pattern (follow exactly)
```gdscript
func request_pickup(trash_id: String) -> void:
	if multiplayer.is_server():
		_server_pickup(trash_id, multiplayer.get_unique_id())
	else:
		_rpc_request_pickup.rpc_id(1, trash_id)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_pickup(trash_id: String) -> void:
	if multiplayer.is_server():
		_server_pickup(trash_id, multiplayer.get_remote_sender_id())
```
Server re-validates existence, range, role and cost every time. State then replicates through `TeamState`.

### 6.6 Testing
Debug → Customize Run Instances (2 instances, 127.0.0.1). Fake latency with Clumsy / `tc netem` / Network Link Conditioner at 0, 80, 150 ms plus a little loss. M4 must pass at 150 ms.

---

## 7. Performance budget (weakest team phone)
60 fps target, 30 fps acceptable. Visible triangles under 150k. Draw calls under 150. One shared material per tint group. `MultiMeshInstance3D` for repeated props. Visibility ranges on far props. Textures at most 1024 px. Audio `.ogg`. No real-time shadows on device. Particles use `CPUParticles3D`, few.

---

## 8. Scope

| In | Out |
|---|---|
| Prologue, Acts 1 to 3 | Rat, fly, toad bosses |
| 6 materials, 8 trash types, 5 inventions | Sorting minigame (P2), research hub, relay network |
| 1 boss, 1 signature puzzle | More zones (teased by radio) |
| 2 towers, team air, mount, split control | Save system, same-phone mode |
| Net Meter and session stats | Voice chat (in-person talking is fine) |

### Risks
| Risk | Mitigation |
|---|---|
| Phones cannot connect directly | Dedicated server, transport abstraction, venue test, recorded video fallback |
| Mount desync | Server-owned state machine, idempotent requests, 50-cycle gate |
| Lag hurts the lure and aim | Owner authority for movement, unreliable aim, test at 150 ms |
| Off-style assets | Style layer, palette, fallback primitives, remove not patch |
| AI code drift | CLAUDE.md, small steps, diff review, validate scripts |
| Claude usage runs out | One step per session, plan mode, free agent continues with same CLAUDE.md |
