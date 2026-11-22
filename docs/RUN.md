# Running Piggyback Planet

1. Set `GODOT_BIN` to the Godot 4.7.2 executable, e.g. `$env:GODOT_BIN = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"`.
2. Two instances on one PC: `python tools/run_two.py` (left window hosts as Bjorn, right window joins 127.0.0.1).
3. Lobby instead: run `& $env:GODOT_BIN --path .` twice; pick "Host as Bjorn" or "Host as Imad" in one, "Join" in the other.
4. Over wifi: both devices on the same network or hotspot. The host's lobby shows "This device: <ip>"; type that IP on the other device and press Join.
5. Windows host firewall (once, admin PowerShell): `New-NetFirewallRule -DisplayName "Piggyback" -Direction Inbound -Protocol UDP -LocalPort 7777 -Action Allow`
6. Keys: WASD move, arrows aim, Space jump, J kick, G grab, E interact (hold at a tower), F use tool, R next tool, M mount, N dismount.
7. Touch controls appear on touchscreens; add `-- --touch` to test them with the mouse on PC.
8. F3 (or the NET button, top-right) toggles the net meter: role, ping, loss, kbps, mount cycles.
