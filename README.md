# SyncRentBeds

Compatibility prototype for **Skyrim Special Edition + Skyrim Together Reborn**.

## Problem

Vanilla `RentRoomScript` assigns a rented inn bed directly to the renting player's ActorBase. Under Skyrim Together Reborn, the second player can inherit the shared dialogue state (the innkeeper already considers the room rented) while still being rejected by the bed's ownership check, especially when joining after the rental occurred.

## v0.2.0 prototype

The prototype now uses two layers:

1. `RentRoomScript.psc` preserves Bethesda's normal rental flow but marks the rented bed with Skyrim's vanilla `PlayerBedOwnership` faction (`Skyrim.esm` FormID `000F2073`).
2. `SyncRentBeds.dll` watches local player activation events. When the local player activates furniture whose current owner is exactly `PlayerBedOwnership`, the plugin temporarily substitutes the local player's ActorBase as owner, retries activation, then immediately restores `PlayerBedOwnership`.

The temporary native substitution is intentionally local-only: it changes `ExtraOwnership` without marking the reference changed, so it should neither persist nor be propagated by STR. Ordinary NPC-owned beds are never touched.

## Preserved vanilla behaviour

- room price and rental duration remain vanilla;
- `Variable09` still controls the innkeeper's rental dialogue;
- `WI.ShowPlayerRoom` is still called;
- rental expiration restores the innkeeper as owner;
- normal NPC beds and furniture are unaffected.

## Requirements

- Skyrim Special Edition / Anniversary Edition
- SKSE
- Address Library / CommonLibSSE-NG compatible runtime setup
- Skyrim Together Reborn for the intended co-op use case

## Build

The project uses CommonLibSSE-NG (`commonlibsse-ng-flatrim`) through vcpkg/CMake. Compile `src/RentRoomScript.psc` separately with Bethesda's Papyrus compiler and place the resulting `RentRoomScript.pex` in `package/Data/Scripts/`. Place the native build output `SyncRentBeds.dll` in `package/Data/SKSE/Plugins/`.

Important when compiling the Papyrus override: put the project source directory before the vanilla source directory in the include path, e.g. `-i="$Project\src;$VanillaSource"`, because both locations contain a script named `RentRoomScript.psc`.

## Prototype test

1. Install the same build on both players.
2. Start Player1 and rent an inn room.
3. Verify the bed owner becomes `PlayerBedOwnership` after rental.
4. Have Player2 join STR after the rental.
5. Player2 activates the same bed.
6. Check `Documents/My Games/Skyrim Special Edition/SKSE/SyncRentBeds.log` for the activation watcher and retry result.
7. Verify Player2 can use / lie in the bed while NPC ownership behaviour remains normal.
8. Verify rental expiration restores the innkeeper's ownership.

## Current status

v0.2.0 is an experimental native activation-bypass prototype. The key point to validate is whether `TESActivateEvent` is emitted early enough when Skyrim rejects an owned bed. If not, the next implementation will hook the pre-ownership activation path instead of relying on the event sink.
