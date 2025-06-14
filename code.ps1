$env:ELECTRON_RUN_AS_NODE = 1
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$codeExe = Join-Path $scriptPath "..\Code.exe"
$cliJs = Join-Path $scriptPath "..\resources\app\out\cli.js"

& $codeExe $cliJs $args
exit $LASTEXITCODE