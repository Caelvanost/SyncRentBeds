# SyncRentBeds

Compatibility prototype for **Skyrim Special Edition + Skyrim Together Reborn**.

## Problem

Vanilla `RentRoomScript` temporarily assigns a rented inn bed directly to the local player's ActorBase. In Skyrim Together Reborn, testing indicates that the innkeeper's rental state (`Variable09`) is synchronized between clients, while the bed reference ownership itself is not.

This produces a split state: the second player can be told that the room has already been rented, but the same bed can still be owned by the innkeeper on that client and remain unusable.

## v0.1.2 prototype solution

SyncRentBeds keeps Bethesda's actor ownership model, but reconstructs it locally on every client from the synchronized innkeeper state:

- the client that rents the room uses the normal player ActorBase ownership;
- while the innkeeper is loaded, the script checks `Variable09` every 2 seconds;
- if `Variable09 >= 1`, the bed is assigned to that client's local player ActorBase;
- if the room is not rented, ownership is restored to the innkeeper;
- polling starts when the innkeeper's cell attaches and stops when it detaches;
- the normal room price, rental timer, dialogue state, and `WI.ShowPlayerRoom` flow are preserved.

This means Player1 can locally see the bed as owned by Kahel while Player2 locally sees the same rented bed as owned by Elir. NPCs do not receive public access because the bed is never made ownerless.

## Requirements

- Skyrim Special Edition / Anniversary Edition
- Skyrim Together Reborn for the intended co-op use case

The v0.1.2 prototype is **Papyrus-only**. It does not require an SKSE DLL or ESP.

## Compatibility

SyncRentBeds overrides Bethesda's `RentRoomScript.pex`, so it conflicts with mods that also replace that script. Ensure SyncRentBeds wins the file conflict for `Data/Scripts/RentRoomScript.pex`.

When compiling, put the project source directory before the vanilla source directory in the Papyrus import path:

```text
-i="$Project\src;$VanillaSource"
```

This is important because both directories contain a `RentRoomScript.psc`.

## Test plan

1. Install the compiled script on both players.
2. Player1 enters an inn and rents the room.
3. Confirm Player1 can use the bed.
4. Confirm `Variable09`/dialogue rental state is visible to Player2 through STR.
5. Have Player2 join the STR server after Player1 has already rented the room.
6. Enter/load the inn on Player2 and wait up to a few seconds for the local sync pass.
7. Inspect the bed: it should be locally owned by Player2's character rather than the innkeeper.
8. Confirm Player2 can activate / lie in the bed.
9. Confirm ordinary NPCs are still excluded by player-specific ownership.
10. After the rental expires, confirm ownership returns to the innkeeper on each client.

Papyrus logging uses `[SyncRentBeds]` markers for rental interception, cell attach/detach, local ownership application, and rental cleanup.
