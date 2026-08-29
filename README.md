# SyncRentBeds

Compatibility prototype for **Skyrim Special Edition + Skyrim Together Reborn**.

## Problem

Vanilla `RentRoomScript` assigns a rented inn bed to the local player's ActorBase. In Skyrim Together Reborn, testing shows that the remote client can observe enough of the innkeeper rental state (`Variable09`) to know a room has been rented, while the bed reference ownership itself is not reliably synchronized.

The Papyrus-only 0.1.x prototypes proved two things:

- Player2 can gain access if the bed ownership is rewritten locally;
- STR/Skyrim can then rewrite that ownership back to the innkeeper, producing visible `Owned` / available oscillation.

Continuously fighting ownership with Papyrus polling is therefore not suitable for the final implementation.

## v0.2.x native prototype

v0.2.x moves access handling into an SKSE/CommonLibSSE-NG plugin.

Papyrus now has only two responsibilities:

1. preserve Bethesda's normal rental flow on the client that actually rents;
2. observe the STR-visible `Variable09` state and mark/unmark the associated bed through a tiny native bridge.

Papyrus no longer rewrites remote-client bed ownership every two seconds.

The native plugin listens for SKSE crosshair changes. When the local player targets a bed that has been marked as rented, the plugin temporarily gives that reference local-player ownership for the duration of the crosshair interaction, so Skyrim should present it as usable and allow activation. When the crosshair leaves the bed, the previous owner is restored. If STR or another mod changes ownership while the temporary override is active, SyncRentBeds avoids overwriting that newer external state during restoration.

This implementation deliberately avoids a global `TESObjectREFR::IsCrimeToActivate()` replacement. CommonLibSSE-NG exposes that engine function, but globally replacing it would affect every activatable reference in the game and requires a carefully preserved original call path. The crosshair-scoped prototype gives us a much narrower and safer test surface.

## Requirements

- Skyrim Special Edition / Anniversary Edition
- SKSE
- Address Library compatible with the installed Skyrim runtime
- Skyrim Together Reborn for the intended co-op use case

## Files

The installed package must contain:

```text
Data/
├── Scripts/
│   ├── RentRoomScript.pex
│   └── SyncRentBedsNative.pex
└── SKSE/
    └── Plugins/
        └── SyncRentBeds.dll
```

## Release build

The repository includes `build/_release.bat`, which automates the complete release build:

1. CMake configuration;
2. Release build of the SKSE DLL;
3. compilation of both Papyrus scripts;
4. copy of the DLL into the package staging directory;
5. creation of `dist/SyncRentBeds-<version>.zip`.

From PowerShell:

```powershell
.\build\_release.bat
```

The script expects the development environment currently used for this project:

```text
Skyrim: C:\Games\Steam\steamapps\common\Skyrim Special Edition
vcpkg: C:\dev\vcpkg
Generator: Visual Studio 18 2026, x64
```

Papyrus compilation keeps the project source directory before the vanilla source directory:

```text
-i="$Project\src;$VanillaSource"
```

This is required because Skyrim also ships `RentRoomScript.psc`.

## Native build

The native plugin uses CommonLibSSE-NG through vcpkg (`commonlibsse-ng`) and the Colorglass vcpkg registry defined by `vcpkg-configuration.json`.

For manual builds, the equivalent commands are:

```powershell
cmake -S . -B build `
    -G "Visual Studio 18 2026" `
    -A x64 `
    -DCMAKE_TOOLCHAIN_FILE="C:\dev\vcpkg\scripts\buildsystems\vcpkg.cmake"

cmake --build build --config Release
```

## Compatibility

SyncRentBeds overrides Bethesda's `RentRoomScript.pex`, so it conflicts with mods that also replace that script. Ensure SyncRentBeds wins the file conflict for `Data/Scripts/RentRoomScript.pex`.

The native plugin modifies ownership only while the local player's crosshair is on a bed that Papyrus has explicitly marked as rented. Ordinary beds and NPC interactions are untouched.

## v0.2.x test plan

1. Install the compiled Papyrus scripts and DLL on both players.
2. Player1 enters an inn and rents the room.
3. Confirm Player1 can use the rented bed normally.
4. Have Player2 join the STR server after Player1 already rented the room.
5. Enter/load the inn on Player2 and wait a few seconds for `Variable09` observation.
6. Aim at the rented bed on Player2.
7. Check whether the prompt remains available rather than alternating to `Owned`.
8. Activate the bed once; no interaction spamming should be necessary.
9. Move the crosshair away and back to the bed several times.
10. Confirm ordinary NPC-owned beds that were not rented remain `Owned`.
11. Check `Documents/My Games/Skyrim Special Edition/SKSE/SyncRentBeds.log` for `Marked rented bed`, `Temporarily granted local access`, and activation-event lines.

If the prompt is still calculated as `Owned` before the SKSE crosshair event applies the temporary access, the next prototype will move the same rented-bed predicate into a lower-level ownership/crime check rather than widening the scope of the workaround.
