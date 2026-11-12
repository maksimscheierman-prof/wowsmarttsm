# Installation

## Target

`E:\WoW\World of Warcraft\_forever_\Interface\AddOns\WoWSmartTSM`

Override with env `WOW_FOREVER_ROOT`.

## Dev install

```powershell
python tools/doctor.py
python tools/install.py --dev
python tools/verify_install.py
```

If Wow.exe is running: files are copied but **activation is not claimed** until `/reload` or restart.

## Release package

```powershell
python tools/package.py
# extract dist/WoWSmartTSM-*.zip into Interface\AddOns\
```

## Uninstall

```powershell
python tools/install.py --uninstall
```

Removes only `WoWSmartTSM`. TSM data untouched. Backups under `backups/`.

## Rollback

Restore a `backups/WoWSmartTSM-preinstall-*` folder to AddOns.
