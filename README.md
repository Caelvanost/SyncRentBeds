# SyncRentBeds

Compatibility prototype for **Skyrim Special Edition + Skyrim Together Reborn**.

## Problem

Vanilla `RentRoomScript` temporarily assigns the rented inn bed directly to the local player's ActorBase. In Skyrim Together Reborn, that actor-specific ownership can leave the second local player seeing the same bed as `Owned`, even though the shared innkeeper state already reports that the room has just been rented.

## Prototype solution

SyncRentBeds v0.1.0 replaces only `RentRoomScript` and changes the temporary rental ownership from the local player ActorBase to Skyrim's vanilla `PlayerBedOwnership` faction (`Skyrim.esm` FormID `000F2073`).

The rest of Bethesda's rental flow is intentionally preserved:

- the room price is removed normally;
- `Variable09` still tracks the innkeeper's rented-room dialogue state;
- `WI.ShowPlayerRoom` is still called;
- the normal rental timer remains active;
- when the rental expires, ownership is restored to the innkeeper.

If `PlayerBedOwnership` cannot be resolved, the script falls back to the vanilla actor-owner behaviour.

## Requirements

- Skyrim Special Edition / Anniversary Edition
- Skyrim Together Reborn for the intended co-op use case

No SKSE plugin or ESP is required by this prototype.

## Compatibility

Because this prototype overrides Bethesda's `RentRoomScript`, it will conflict with mods that also replace that script. A later version may use a native hook or a compatibility mechanism if testing shows that a script override is too restrictive.

## Build status

The repository currently contains the Papyrus source only. `RentRoomScript.psc` must be compiled to `RentRoomScript.pex` before installing it in `Data/Scripts/`.

## Initial STR test

1. Install the compiled script on both players.
2. Join the same STR party and enter a vanilla inn.
3. Player1 rents the room.
4. Confirm Player1 can use the rented bed.
5. On Player2, inspect the same bed and verify it is no longer blocked as `Owned`.
6. Have Player2 activate / lie in the rented bed.
7. Verify the innkeeper still considers the room rented and does not charge Player2 again.
8. Leave enough game time for the rental to expire and verify the bed returns to its normal owner.

Papyrus logging includes `[SyncRentBeds]` markers for rental and cleanup events.
