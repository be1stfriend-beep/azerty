# BRIEF: Piggyback Planet (the vision, in one page)

This file is the single source of truth. If it conflicts with SPEC.md, BUILD_PLAN_7H.md, PROMPTS.md or PROMPTS_2.md, **this file wins**.

## Repository rule (read first)
- There is exactly ONE Godot project: `project.godot` at the repository root (the folder you were started in).
- Never create a new Godot project, never create a nested project folder, never run Godot to generate a project. If asked "how do I do X", answer in text and change nothing.
- Never create a second main scene, second autoload set or second export preset.

## The game in two sentences
Two survivors, **Bjorn** and **Imad**, in a poisoned junk world turn trash into inventions and use them to purify the land, one tower at a time, until colour comes back. One player carries the other: **one body, two phones**.

Theme: **nothing gets thrown away, everything gets invented.**

## Roles (final)
| | Bjorn (No Hands) | Imad (No Legs) |
|---|---|---|
| Moves | Run (fast), jump (high), kick | Crawl (slow), no jump |
| Hands | None. Cannot grab, craft or use tools | Tongs, broomstick, crafting, recycling, tower activation |
| Damage | **Kick: small damage** (1 per hit, 2 on a stunned enemy, 0.7 s cooldown) | **Broomstick: strong damage** (3 per hit, only on a stunned enemy) |
| Co-op value | Speed, jumping to ledges and plates, luring enemies, carrying Imad | Collecting, building, activating, finishing enemies |

Merged: Bjorn steers and can still kick; Imad aims and uses tools. Merged jump is lower. Either can dismount if space is free.

## World and loop
- **Dome:** clean air, Recycler and Bench. Enemies cannot enter.
- **Wasteland:** dusty orange haze. Air drains outside the Dome and outside active tower radii.
- **Loop:** scavenge trash, recycle into materials (plastic, metal, paper, compost, wood, later electronics), craft at the Bench, activate a purification tower, colour returns.
- **Towers** need a Filter (and a Battery for tower 2). Imad holds interact for 5 s while Bjorn defends.
- **Bosses:** vermin. Now: the Cockroach. Later: rats, flies, toads.
- **Nothing is deleted:** trash dropped on knockout stays in the world.

## Story beats (about 10 minutes)
1. Prologue (cut; replaced by a short intro line).
2. Solo: the two start apart, each thinking they are alone, and find each other.
3. Reunion, the mount, the first excursion, the scripted cockroach chase back to the Dome, the Filter, tower 1.
4. Broomstick, lure-and-ambush the roach (Bjorn lures and kicks, Imad is on the perch and brooms), the gate opens, industrial zone, electronics, Battery, tower 2, radio ending.

## What "colour returns" means (exact)
- Outside every active tower: the whole world is dusty orange, desaturated.
- Inside a tower's radius (in WORLD space, around the tower's world position): ground and props blend to lush green and teal, with a soft 4 m edge, over 3 s.
- The green must be centred on the tower and nowhere else. A ring marker on the ground shows the radius.

## "Working" means (definition of done for the whole game)
Two phones can go from the lobby to the end card, twice in a row, without restarting and without any soft-lock. If a state can get stuck (mounting, dismounting, perch, tower hold, roach fight), a watchdog must recover it.

## Style
Warm, dusty, rusty world; cool, saturated, chunky characters; one palette, one shader family, no emoji, no default grey materials, no random scatter (levels are hand-authored).
