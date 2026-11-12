$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
python tools/package.py @args
exit $LASTEXITCODE
