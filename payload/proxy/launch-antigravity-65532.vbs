Option Explicit
Dim shell, env, files, appDir
Set shell = CreateObject("WScript.Shell")
Set env = shell.Environment("PROCESS")
env("HTTP_PROXY") = "http://127.0.0.1:65532"
env("HTTPS_PROXY") = "http://127.0.0.1:65532"
env("ALL_PROXY") = "http://127.0.0.1:65532"
env("NO_PROXY") = "localhost,127.0.0.1,::1"
Set files = CreateObject("Scripting.FileSystemObject")
appDir = shell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Programs\antigravity"
shell.CurrentDirectory = appDir
shell.Run Chr(34) & appDir & "\Antigravity.exe" & Chr(34) & " --proxy-server=http://127.0.0.1:65532", 1, False
