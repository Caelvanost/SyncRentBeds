# SyncRentBeds

Compatibility prototype for **Skyrim Special Edition + Skyrim Together Reborn**.

## Problem

Vanilla `RentRoomScript` temporarily assigns a rented inn bed directly to the local player's ActorBase. In Skyrim Together Reborn, testing indicates that the innkeeper's rental state (`Variable09`) can be observed by remote clients, while the bed reference ownership itself is not synchronized.

This produces a split state: the second player can be told that the room has already been rented, but the same bed can still be owned by the innkeeper on that client and remain unusable.

Further testing showed that `Variable09` can oscillate between `1.0` and `0.0` on a remote client while the room is still effectively rented.

## v0.1.4 prototype solution

SyncRentBeds reconstructs rented-bed ownership locally on every client and now uses a local latch so transient `Variable09=0` updates do not revoke access:

- the client that rents the room uses the normal player ActorBase ownership;
- while the innkeeper is loaded, the script checks `Variable09` every 2 seconds;
- the first observed `Variable09 >= 1` latches the room as rented on that client;
- while latched, the bed remains owned by that client's local player ActorBase even if `Variable09` temporarily returns to `0`;
- a single `Variable09 >= 1` resets the release counter;
- the latch is released only after 15 consecutive `Variable09=0` polls (about 30 seconds), or immediately when local vanilla `ClearRoom()` runs;
- polling starts when the innkeeper's cell attaches and stops when it detaches;
- the normal room price, rental timer, dialogue state, and `WI.ShowPlayerRoom` flow are preserved.

This means Player1 can locally see the bed as owned by Kahel while Player2 locally sees the same rented bed as owned by Elir. NPCs do not receive public access because the bed is never made ownerless.

## Requirements

- Skyrim Special Edition / Anniversary Edition
- Skyrim Together Reborn for the intended co-op use case

The v0.1.4 prototype is **Papyrus-only**. It does not require an SKSE DLL or ESP.

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
4. Have Player2 join the STR server after Player1 has already rented the room.
5. Enter/load the inn on Player2 and wait a few seconds for the local sync pass.
6. Inspect the bed: it should be locally owned by Player2's character rather than the innkeeper.
7. Confirm Player2 can activate / lie in the bed.
8. Observe that transient `Variable09=0` updates no longer flip ownership back to the innkeeper.
9. Confirm ordinary NPCs are still excluded by player-specific ownership.
10. After the rental genuinely expires, confirm the latch releases and ownership returns to the innkeeper.

Papyrus logging uses `[SyncRentBeds]` markers for rental interception, latch activation/release, transient zero suppression, cell attach/detach, local ownership application, and rental cleanup.
