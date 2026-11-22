# Running Piggyback Planet

1. Set `GODOT_BIN` to the Godot 4.7.2 executable, e.g. `$env:GODOT_BIN = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"`.
2. Two instances on one PC: `python tools/run_two.py` (left hosts, right joins 127.0.0.1), or run `& $env:GODOT_BIN --path .` twice and use the login screen.
3. Login screen: type a name, pick "Host as Bjorn" or "Host as Imad" in one instance and "Join" in the other.
4. Over Wi-Fi: both devices on the same network or hotspot. The host's Network panel lists its private addresses (`192.168.x.x`, `10.x.x.x`); type one on the other device and press Join.
5. Phones: turn **mobile data off**, otherwise Android may route the game through it.
6. Windows host: the Wi-Fi must use the **Private** network profile, or Windows blocks incoming LAN traffic.
7. Windows host firewall (once, admin PowerShell): `New-NetFirewallRule -DisplayName "Piggyback" -Direction Inbound -Protocol UDP -LocalPort 7777 -Action Allow`
8. Keys: WASD move, arrows aim, E context action (grab, recycle, craft, climb on), Space jump, J kick, M mount, N dismount. Add `-- --touch` for touch buttons on PC.
9. F3 (or the NET button, top-right) toggles the net meter: role, names, ping, loss, kbps.
10. Slice self-test (one process, no network): `& $env:GODOT_BIN --headless --path . -- --autotest-slice` prints PASS/FAIL per step, exit code 1 on any FAIL.
