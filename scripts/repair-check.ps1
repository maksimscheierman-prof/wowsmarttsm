$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
python tools/repair_check.py @args
exit $LASTEXITCODE
