# PROMPTS_4: Login page and prologue

How to use: type exactly
`Read CLAUDE.md and docs/BRIEF.md, then do ONLY prompt <id> in docs/PROMPTS_4.md.`
Run `/clear` between prompts. Same coordinate system as docs/PROMPTS.md. Do not rewrite `core/net.gd` and do not edit `export_presets.cfg`.

---

## L1 · Login page (replaces the P3 lobby look, keeps its logic)

Goal: a clear first screen where two phones (and a PC) can connect on the same network and see what is going on.

1. Rework `game/ui/lobby.gd` into a login screen. All UI built in code, one font, palette colours, no emoji, landscape, safe at 1920x1080 and 2400x1080, buttons at least 100 px tall, font size at least 40.
2. Content:
   - Title "PIGGYBACK PLANET" (from `data/config.json`) with a small wobble animation on the letters, a calm dusty background drawn with the palette (flat shapes, no assets).
   - **Player name** field, default "Player", saved in `user://settings.cfg`.
   - **Server address** field, prefilled with the last used address, plus up to 3 recent addresses as tappable buttons.
   - Buttons: "Host as Bjorn", "Host as Imad", "Join". Remember the last choice.
   - A **Network** panel: shows every private IPv4 address of this device (ranges 192.168.x.x, 10.x.x.x, 172.16 to 31.x.x), one per line, with the port. Hide loopback and link-local (169.254) addresses.
   - Status line with colour: idle, "Hosting. Waiting for partner...", "Connecting...", "Connected as <role>", errors.
3. Connection behaviour:
   - Joining has an 8 s timeout (a Timer in the lobby, do not edit `net.gd`). On timeout or `join_failed`, show: "No answer from <ip>. Check: same Wi-Fi, host game is running, firewall allows UDP 7777, mobile data is off."
   - While hosting, show "<name> joined as <role>" as soon as the partner connects, for 1.5 s, then the match starts as before.
   - Partner names are exchanged with one reliable RPC (in `Game`, not in `net.gd`) and stored in `Game.player_names[Characters.Character]`. Show them in the Net Meter next to the role.
   - Cancel button while hosting or connecting; it leaves cleanly and returns to the idle state.
4. `--host` and `--join <ip>` command-line flags still skip the screen. `--dev-level` still skips it.
5. Update `docs/RUN.md`: the Network panel, the firewall line, "mobile data off", "private network profile".

Done when: two windows connect through the screen, a wrong IP shows the timeout message after 8 s, names show in the meter, and `python tools/check.py` (or the headless check) is clean.

---

## L2 · 15-second prologue (Undertale / Deltarune style)

Goal: a short, readable intro that plays on both devices in sync before the level loads. Total length 14 s, never more than 15 s.

1. `game/ui/prologue.gd` (Control, all in code). Rendered into a `SubViewport` of 320x180 pixels, scaled up with nearest-neighbour filtering to fill the screen (black bars if needed) for a chunky pixel look. Drawings are flat shapes made in code with palette colours (rects, polygons), no image assets and no generated text in images. Text is a bottom strip on black: white, typewriter speed 30 characters per second, with a short blip sound per character.
2. Sound: generate the blip in code (a 10 ms square wave, slightly different pitch per character, low volume) as an `AudioStreamWAV`. If `core/sfx.gd` exists use it, otherwise create a minimal one. A faint low drone during beat 2 and 3. Put the volume in `balance.json` (`sfx_master`).
3. Timeline (put the times in `balance.json` as `prologue_beat_seconds`, array of 5, summing to 14):
   - Beat 1, 3 s: dusk, warm orange sky, five small houses with lit windows and a few tiny walking figures. Text "Once, there was a town."
   - Beat 2, 3 s: a grey smoke column grows on the right, windows go dark one by one, the colours drain to grey. Text "Then there was smoke."
   - Beat 3, 3 s: the empty street, one lamp flickering. Text "Then it was quiet."
   - Beat 4, 3 s: two small figures at the far left and far right of a wide empty road: one tall and thin in cyan, one short and wide in blue. A long gap between them. Text "Two stayed. Each thought he was the only one."
   - Beat 5, 2 s: black. "PIGGYBACK PLANET" bounces in with a blip, then fades out into the level.
   Nothing graphic: the loss is implied, never shown. Humour and warmth, no pity.
4. Sync and flow (host authoritative):
   - The host's `Game.start_match()` sends a reliable RPC "play prologue"; both peers play it locally, then each sends a reliable "prologue_done". The host loads the level on both when both are done, or after 17 s, whichever comes first.
   - A tap, click, Space or Enter on either device shows "Skip" for 1 s then skips for both: the device sends a reliable "skip request", the host broadcasts "skip" and everything proceeds.
   - `--no-prologue`, `--dev-level` and the autotest flags skip it.
6. Tone check: no names of the characters' codenames, no text in images, no emoji.
7. Test: `python tools/run_two.py` shows the prologue on both windows within 0.5 s of each other, skip works from either side, the level loads on both.

Done when: both instances play the 14 s prologue in sync and enter the level, skip works, and total duration is under 15 s.
