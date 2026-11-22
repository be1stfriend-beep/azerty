# Running Piggyback Planet

1. Set `GODOT_BIN` to the Godot 4.7.2 executable, e.g. `$env:GODOT_BIN = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"`.
2. Two instances on one PC: `python tools/run_two.py` (left window hosts as Bjorn, right window joins 127.0.0.1). `--host`, `--join <ip>` and `--dev-level` skip the login screen.
3. Login screen instead: run `& $env:GODOT_BIN --path .` twice. Type a name, then pick "Host as Bjorn" or "Host as Imad" in one window and "Join" in the other. Name, address, the last 3 addresses and the last choice are saved in `user://settings.cfg`.
4. Over Wi-Fi: both devices on the same network or hotspot, **mobile data off** on phones (otherwise Android may route through it).
5. The host's **Network** panel lists every private address of the device (`192.168.x.x`, `10.x.x.x`, `172.16-31.x.x`) with the port. Type one of them on the other device and press Join. Recent addresses are one tap away.
6. If nothing answers within 8 s the status line says so: same Wi-Fi, host running, firewall allows UDP 7777, mobile data off. Cancel stops hosting or joining at any time.
7. Windows host: the Wi-Fi must use the **Private** network profile (Settings, Network, Wi-Fi, your network, Private), otherwise Windows blocks incoming LAN traffic.
8. Windows host firewall (once, admin PowerShell): `New-NetFirewallRule -DisplayName "Piggyback" -Direction Inbound -Protocol UDP -LocalPort 7777 -Action Allow`
9. Keys: WASD move, arrows aim, Space jump, J kick, G grab, E interact (hold at a tower), F use tool, R next tool, M mount, N dismount.
10. Touch controls appear on touchscreens; add `-- --touch` to test them with the mouse on PC.
11. F3 (or the NET button, top-right) toggles the net meter: role and both player names, ping, loss, kbps, mount cycles.
