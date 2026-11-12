$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
python tools/diagnose.py @args
exit $LASTEXITCODE
