# Flixbox operator CLI demo (day-0 / day-2)
# Render: vhs docs/images/shared/cli-quickstart.tape
# Safe against a live stack: status + dry-run only (no wipe, no secret prompts).

Output docs/images/shared/cli-quickstart.gif

Set FontSize 18
Set Width 1100
Set Height 620
Set Padding 16
Set Theme "Catppuccin Mocha"
Set TypingSpeed 45ms
Set PlaybackSpeed 1.0

Hide
Type "cd /home/aazario/DevOps/github.com/aleaz/flixbox"
Enter
Sleep 400ms
Show

Type "./bin/flixbox status"
Enter
Sleep 4s

Type "clear"
Enter
Sleep 400ms

Type "./bin/flixbox configure --dry-run"
Enter
Sleep 6s

Type "clear"
Enter
Sleep 400ms

Type "./bin/flixbox homepage refresh --dry-run"
Enter
Sleep 4s

Sleep 2s
