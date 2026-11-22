# PROMPTS_5: The vertical slice (recycling loop first)

How to use: type exactly
`Read CLAUDE.md, docs/BRIEF.md and the "Slice rules" section of docs/PROMPTS_5.md, then do ONLY prompt S<n> in docs/PROMPTS_5.md.`
Run `/clear` between prompts. Same coordinate system as docs/PROMPTS.md (+Z south toward the camera, Dome at the origin).

---

## Slice rules (these override BRIEF.md and every older doc where they conflict)

**Goal: one short, fully playable loop. Gameplay must exist before anything else.**

The loop, in order:
1. **Login** (connectivity): host or join over the local network.
2. **Dome tutorial:** both players start inside the Dome and learn the controls while collecting plenty of trash.
3. **Recycle:** Imad recycles the trash at the Recycler. Materials appear in the HUD.
4. **Craft the Mask** at the Bench. The Mask unlocks going outside.
5. **Outside:** the pair goes into the wasteland and collects more trash (air drains, the Mask slows it).
6. **The bug (cockroach) appears** and chases them.
7. **Return to the Dome:** the roach cannot enter. Slice complete card.

**What you must NOT do** (frozen until the slice works): towers, filters, batteries, tower 2, industrial zone, perch and pillar fight, puzzles (plates, vents, doors), prologue, reunion start, new recipes, new enemies, music, extra polish, refactors, new systems. If a feature is not in the loop above, do not build it, do not rework it, do not delete it either (leave existing code alone, just do not spawn it in the slice level).

**Rules for the slice**
- The slice level is `data/levels/slice.json` and `data/config.json` gets `"start_level": "slice"`. The existing `main.json` stays untouched.
- **One action button.** Imad's `interact` (E on keyboard, one big touch button with a changing label) does everything contextually: Grab, Recycle, Craft, Mount. The label always says what will happen. Bjorn has Jump and Kick, and Mount/Dismount when relevant.
- The world must tell the player what to do: a world-space prompt above the nearest usable thing, a ring highlight on the nearest grabbable trash, and one objective line at the top of the screen.
- **Characters:** Bjorn has NO hands (sleeves end in rounded cuffs, nothing hand-shaped). Imad has NO legs, NO cart and NO box: he crawls on the ground using his arms (see S2). He is short and wide and low to the ground.
- Nothing gets thrown away: on knockout carried trash drops at the spot as pickable trash.
- Art stays procedural and ugly-but-readable for now. Art comes after the slice works.
- If something is ambiguous, pick the simplest option, implement it, list it under "Assumptions". Do not ask questions.
- Every prompt ends with: the check, a commit, and manual test steps for two instances.

---

## S1 · Slice level, data and trash

1. New `data/levels/slice.json` and `"start_level": "slice"` in config. `Game` loads the level named in config (keep `--dev-level` working).
2. Layout (hand-authored, no random scatter):
   - Dome radius 14 at the origin, Recycler at (-6,0,-4), Bench at (6,0,-4), spawn markers bjorn (-3,0,4) and imad (3,0,4). Nothing else from `main.json` (no tower, pillar, perch, gate, puzzles).
   - **Dome trash: 16 pieces** in 4 hand-made clusters (about (-9,0,6), (9,0,6), (0,0,10), (-4,0,-9)), at least 2 m from any station: 6 bottles, 4 cans, 3 cardboard, 3 planks.
   - **Wasteland trash: 18 pieces** in 5 clusters between z=20 and z=40 (south of the Dome): 4 apple cores, 4 bottles, 4 cans, 3 cardboard, 3 planks. Add a few barrels, crates and tyres as obstacles and landmarks so there is a visible route, plus 2 scrap towers.
   - A `roach_hunt` marker is NOT placed; the roach spawn is computed in S5.
3. Balance keys: `recycle_seconds_per_item 0.3`, `slice_outside_trash_needed 5`, `air_drain_mask_mult 0.6`. Keep the rest.
4. Recipes: `mask` (plastic 2, paper 2, invention name "The Breathe-Easy 3000"). Cardboard yields 2 paper, so one cardboard and two bottles are enough.
5. Run `tools/validate_data.py`, extend it if needed to check the slice level.

Done when: the slice level loads with all 34 trash pieces visible, styled, and reachable, nothing else from the old level.

---

## S2 · Characters (fix the bodies)

1. **Bjorn (1.9 m, tall and thin):** remove anything that looks like a hand. Each arm is a single sleeve ending in a rounded cuff of the parka colour, nothing shaped like a hand or finger. Arms swing gently when he runs. Keep the beanie with a red pompom, huge boots, big dopey eyes. Add `Saddle` marker on his upper back if missing.
2. **Imad (short and wide, no legs):** remove the cart and every box. Body: a stocky torso with a cobalt vest, thick arms with round hands, goggles on dark curly hair, and a short rounded lower body (the overalls end in a tapered, tied-off tail) so it is clear he has no legs. His torso is low to the ground (about 0.5 m off the floor).
3. **Crawl animation:** driven by horizontal speed, in `update_wobble` or a new `update_crawl`. The arms alternate: one reaches forward and plants, the body lunges and drags the rounded lower body behind it, with a small squash and stretch and a leaning torso. Moving faster speeds up the cycle. Idle: gentle breathing. Slow (`imad_crawl`), no jump.
4. **Mounted pose:** when merged, Imad's torso is upright on Bjorn's back with the arms raised forward over his shoulders; the crawl animation stops.
5. Tongs: on Imad's back when idle, extended forward when he grabs (see S3). Visible and chunky.
6. Take a screenshot of each character (idle, moving, merged) using `--screenshot` (create the minimal flag if it is missing: after N frames save the viewport PNG, then quit) and check there are no hands on Bjorn and no box on Imad.

Done when: Bjorn has no hands, Imad crawls with his arms and has no cart, and both read clearly at phone size.

---

## S3 · Controls that make sense

1. **Contextual action for Imad** (E key and one big touch button, minimum 150 px, label in text). A single function `Interaction.resolve(player)` picks the action by priority:
   - trash in tongs range (`tongs_radius`) and carrying fewer than `carry_capacity`: label "GRAB"
   - Recycler in range and carrying something: label "RECYCLE (n)"
   - Bench in range: label "CRAFT"
   - Bjorn in `mount_range` (solo): label "CLIMB ON"
   - merged: label "DISMOUNT" only when nothing else applies
   - nothing: the button is dimmed and says "-"
2. **Highlight:** the single nearest grabbable trash in range gets a bouncing ring in the palette (visible on both screens, only the local player's target). The nearest station in range shows a world-space prompt ("Recycler: bring trash here", "Bench: craft").
3. **Grab feels right:** pressing the button extends the tongs to the trash in 0.25 s, the trash shrinks into Imad's back sack, a small pop, carried count updates ("n/8"). If full: a prompt "Full. Take it to the Recycler".
4. **Merged assist:** when Imad is riding, the tongs auto-target the nearest trash within `tongs_reach` of the body (ring highlight), and the same button grabs it. The right stick still overrides the aim. Everything else keeps working as before.
5. **Bjorn:** Jump and Kick buttons, nothing confusing. Kick plays an animation and nudges nearby loose trash lightly (visual only, no gameplay effect needed).
6. Keyboard: E context action, Space jump, J kick, M mount (still works), N dismount. Update touch buttons through `Events.context_changed`.
7. **Objective line** at the top of the screen (one line): "Collect trash around the Dome" while the stash is empty, "Recycle your trash at the Recycler" when carried is at least 3 or capacity, "Craft a Mask at the Bench" when the mask is affordable, "Go outside and find more trash" after the mask, "Get back to the Dome!" while the roach is hunting, "Slice complete" at the end. Texts from `data/hints.json` (create it).

Done when: a person who has never played can collect, recycle and reach the bench by following the button label, the highlight and the objective line only.

---

## S4 · Recycling and crafting that feel good

1. **Recycler:** pressing RECYCLE moves the carried items into the hopper one at a time, every `recycle_seconds_per_item` seconds, each with a small arc and a pop; a coloured material block (palette colour per material) comes out of the chute and flies to the matching HUD counter. A floating "+1 plastic" appears. The Recycler shakes slightly while working. Carrying nothing near it shows "Bring trash here".
2. **Server rule:** the host does the recycling (`request_recycle`) and replicates the stash through `TeamState`; both screens see the same animation.
3. **Carried trash is visible:** show up to 8 small trash props on Imad's back sack (or on the pair when merged), one per carried item.
4. **Bench menu:** CRAFT opens a large, simple menu with the Mask card: cost shown as coloured squares with counts ("2 plastic, 2 paper"), green when affordable, "Need 1 more paper" when not. An "Invent" button. A greyed second card "Filter (later)" shows the next goal. Close button. Works for Imad solo or riding.
5. **Craft moment:** on Invent, the host deducts materials, adds `mask` to inventory, and both screens show the Invention Card for 2.5 s ("INVENTED: The Breathe-Easy 3000") with a small spinning mask drawn from primitives, plus a chime (generated in code, short). Imad visibly wears the mask afterwards (a small primitive on his face).
6. **HUD:** air bar top-left, carried "n/8" bottom-centre, stash top-right as coloured squares with names and numbers, objective line. One font, palette colours.
7. **Mask unlocks the outside:** until `mask` is in the inventory, a player who walks to the Dome edge is pushed back inward (clamp on each player's own controller using the shared TeamState; no collision geometry) and sees "You need a mask to go outside" (at most once every 5 s). Posts around the Dome edge glow red until the mask exists and green afterwards. After the mask, air drain outside is multiplied by `air_drain_mask_mult`.

Done when: collect 8 items, recycle them with visible feedback, see the stash fill, craft the Mask, see the posts turn green.

---

## S5 · Outside, the bug, and the way back

1. **Outside:** air drains outside the Dome as before (with the mask multiplier). The HUD shows an arrow at the screen edge pointing toward the Dome whenever the local player is outside. If air runs out: both respawn at the spawn markers, mount forced SOLO, carried trash dropped at the knockout spot as pickable trash (nothing is deleted).
2. **Trigger:** the hunt starts once the pair has collected `slice_outside_trash_needed` pieces from outside the Dome, or when any player is more than 28 m from the Dome centre, whichever comes first. Only once per run (and again after a knockout respawn if it was in progress: it resets).
3. **The roach:** reuse the existing cockroach code. It spawns 22 m behind the players (on the side away from the Dome), plays a warning (screen shake, growl from `core/sfx.gd` or a generated sound, objective line "Get back to the Dome!"). It uses Chase, WindUp and Charge only (no pillar fight in the slice). Its speed must be beatable by Bjorn alone or the merged pair (`merged_speed`), but not by Imad crawling alone: the players need to merge and run.
4. **Safe zone:** the roach never enters the Dome ring. If the players are inside, it stops at the edge, roars (windup tell), then flees back to where it came from and is removed after 4 s.
5. **Slice complete:** when the hunt is over and both players are inside the Dome, show a card "THE BUG GAVE UP. Mask invented. Next: the Filter." with a Restart button (host restarts the match for both).
6. Make sure partner-lost and restart work from every state of the slice.

Done when: collect outside, get chased, run back, the roach stops at the Dome, the card appears; running out of air respawns both without losing trash.

---

## S6 · Slice test and network check

1. Add `--autotest-slice` (extend the existing harness, no second instance): the host acts as both characters through the server request functions, and plays the loop quickly: grab trash, recycle, craft the Mask, check the barrier lifts, grab outside trash, trigger the hunt, return to the Dome, reach the slice complete state. Print PASS or FAIL per step, exit code 1 on any FAIL.
2. Fix every FAIL with the smallest change.
3. Write `docs/RUN.md` (10 lines): how to run two instances, how to join over Wi-Fi, the firewall line (`New-NetFirewallRule -DisplayName "Piggyback" -Direction Inbound -Protocol UDP -LocalPort 7777 -Action Allow`), mobile data off, F3 for the meter.
4. In the final message list the 10 manual checks the human should do on two phones (one line each).

Done when: `--autotest-slice` prints all PASS.

---

## S7 · STRETCH: Bjorn kicks bins (only if time remains)

1. New entity `bin` (a chunky overflowing bin, procedural prop), `kickable`. Bjorn's kick, validated by the host, makes it spill 3 pieces of trash (ids deterministic, appear around the bin as pickable trash, bin becomes empty). 4 bins in the slice level, 2 inside the Dome and 2 outside.
2. Imad cannot spill bins, Bjorn cannot pick up the spilled trash. This gives Bjorn a role in the recycling loop.
3. Add to the objective hints: "Kick the bin, Bjorn" (shown to Bjorn only).

Done when: kicking a bin spills trash on both screens and Imad can collect it.
