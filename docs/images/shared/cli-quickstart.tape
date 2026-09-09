# Flixbox operator CLI demo — cold start (Direct)
# Render from repo root: vhs docs/images/shared/cli-quickstart.tape
# Lab: free host :8080 (default QBITTORRENT_PORT); writable DATA_DIR/CONFIG_DIR from .env.example
#
# Pacing: keep PlaybackSpeed near 1.3–1.5 so operators can read success lines.
# Prefer longer Sleep holds over speeding up the whole tape (README marketing review).

Output docs/images/shared/cli-quickstart.gif

Set FontSize 18
Set Width 1100
Set Height 620
Set Padding 16
Set Theme "Catppuccin Mocha"
Set TypingSpeed 50ms
Set PlaybackSpeed 1.4
Set WaitTimeout 15m

Type "rm -f .env"
Enter
Sleep 600ms

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
