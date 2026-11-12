$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
python tools/doctor.py @args
exit $LASTEXITCODE
