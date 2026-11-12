$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
python tools/test_runner.py @args
exit $LASTEXITCODE
