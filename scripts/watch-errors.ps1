$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
python tools/watch_errors.py @args
exit $LASTEXITCODE
