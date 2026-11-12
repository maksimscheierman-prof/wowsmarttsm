$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
python tools/install.py --dev @args
exit $LASTEXITCODE
