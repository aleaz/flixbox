# Flixbox operator CLI demo — cold start + wire (Direct)
# Render from repo root: vhs docs/images/shared/cli-quickstart.tape
# Lab: free host :8080; writable DATA_DIR/CONFIG_DIR from .env.example
#
# Public GIF rules:
# - Visible: cp .env.example → init → up → status → configure
# - Lab-only rm of a leftover .env stays in Hide, then clear (must not appear in scrollback)
# - PlaybackSpeed ~1.4 so success lines stay readable

Output docs/images/shared/cli-quickstart.gif

Set FontSize 18
Set Width 1100
Set Height 620
Set Padding 16
Set Theme "Catppuccin Mocha"
Set TypingSpeed 50ms
Set PlaybackSpeed 1.4
Set WaitTimeout 20m

# Lab prep — never leave rm visible in the GIF scrollback
Hide
Type "rm -f .env"
Enter
Sleep 200ms
Type "clear"
Enter
Sleep 300ms
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
Sleep 3s

Type "clear"
Enter
Sleep 600ms

Type "./bin/flixbox configure"
Enter
Wait
Sleep 5s
