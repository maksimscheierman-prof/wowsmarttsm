$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
python tools/verify_install.py @args
exit $LASTEXITCODE
