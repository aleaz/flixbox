# Flixbox operator CLI demo — cold start (Direct)
# Render from repo root: vhs docs/images/shared/cli-quickstart.tape
# Lab: free host :8080 (default QBITTORRENT_PORT); writable DATA_DIR/CONFIG_DIR from .env.example
#
# Public GIF rules:
# - Visible steps only: cp .env.example → init → up → status.
# - Pacing: PlaybackSpeed ~1.4; hold success lines (not PlaybackSpeed 3.0).
# - Lab prep (paths/ports, ensuring no stale .env) stays in Hide + clear before Show.

Output docs/images/shared/cli-quickstart.gif

Set FontSize 18
Set Width 1100
Set Height 620
Set Padding 16
Set Theme "Catppuccin Mocha"
Set TypingSpeed 50ms
Set PlaybackSpeed 1.4
Set WaitTimeout 20m

Hide
Type "rm -f .env"
Enter
Sleep 200ms
Show

Type "cp .env.example .env"
Enter
Sleep 800ms

Type "./bin/flixbox init --non-interactive"
Enter
Wait+Screen /Init complete/
Sleep 2s

Type "clear"
Enter
Sleep 600ms

Type "./bin/flixbox up"
Enter
Wait+Screen /Stack started/
Sleep 2s

Type "clear"
Enter
Sleep 600ms

Type "./bin/flixbox status"
Enter
Wait
Sleep 5s
