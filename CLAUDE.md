# CLAUDE.md: Piggyback Planet

Godot 4.7.2, GDScript (static typing), 3D, Compatibility renderer, Android landscape, 2-player online co-op.
You are working on Windows with PowerShell inside VS Code. Tools are Python scripts, never .sh.
Read this file, then docs/BRIEF.md (always), then ONLY the prompt named in the task. docs/BRIEF.md wins over every other doc. Read SPEC sections only when the prompt names them.

## How to work (very important)
- NEVER ask the user a question. NEVER enter plan mode. Decide, implement, finish.
- If something is ambiguous, pick the simplest option that satisfies the prompt, implement it, and list it under "Assumptions" at the end.
- Do exactly the prompt. No extra features, no refactors, no new systems. A working prototype beats a complete one.
- At the end: run the check below, then `git add -A` and `git commit -m "<prompt id>: <title>"`.
- Final message format, max 15 lines: what works, manual test steps (two instances), Assumptions, anything unfinished.

## Check (run before finishing)
- If the env var GODOT_BIN is set, run: `& $env:GODOT_BIN --headless --path . --quit-after 120` and fix every SCRIPT ERROR / parse error. Repeat until clean.
- If GODOT_BIN is not set, skip this and say so in the final message. Re-read your own code for typos instead.
- If you changed data: `python tools/validate_data.py`.

## Code rules
- Static typing everywhere. snake_case files/functions, PascalCase classes, past-tense signals.
- Content in `data/*.json`, numbers in `data/balance.json`. No magic numbers in code.
- Build everything in code. The only hand-written .tscn allowed is `main.tscn` (a root Node with a script). Do not write other scenes.
- Never reference asset file paths in gameplay code. Use ids from `data/prefabs.json`. A missing model must fall back to a procedural prop.
- Every visible mesh gets the style layer (`Style.apply`). Never ship default grey Godot materials.
- Scripts under ~200 lines. Comments explain why, never what. No dead code, no TODO stubs.
- No emoji in UI or code. Text and simple shapes only.

## Networking (non-negotiable)
- Listen server: the host is the server and also plays. `core/net.gd` already exists and is the base. Do not rewrite it; only fix real errors.
- The host validates all gameplay state. Clients ask, host decides, state replicates. Every `@rpc` states mode, call type and transfer mode explicitly.
- Never assume peer id 1 is a particular character. Use `Net.peer_for_character()` and `Net.own_character()`.
