' EduVerse Email Server Auto-Start Script
' This script runs the email server silently in the background

Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = "C:\Users\Anees\Desktop\EduVerse\email-server"
WshShell.Run "cmd /c node server.js", 0, False
