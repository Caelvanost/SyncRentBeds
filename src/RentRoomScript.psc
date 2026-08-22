Scriptname RentRoomScript extends Actor Conditional
{STR-friendly replacement for the vanilla inn room rental script.}

ObjectReference Property Bed Auto
{Bed rented by this innkeeper.}

WIFunctionsScript Property WI Auto
{Pointer to WIFunctionsScript attached to the WI quest.}

Faction PlayerBedOwnershipFaction = None

Faction Function GetPlayerBedOwnershipFaction()
    If PlayerBedOwnershipFaction == None
        PlayerBedOwnershipFaction = Game.GetFormFromFile(0x000F2073, "Skyrim.esm") as Faction
    EndIf

    Return PlayerBedOwnershipFaction
EndFunction

Function RentRoom(DialogueGenericScript pQuestScript)
    Debug.Trace("[SyncRentBeds] RentRoom intercepted")

    Faction sharedBedFaction = GetPlayerBedOwnershipFaction()

    If sharedBedFaction != None
        ; Mark rented beds with Skyrim's dedicated player-bed ownership faction.
        ; The native SyncRentBeds plugin recognizes this exact owner and grants
        ; the local player a one-shot activation bypass without opening the bed
        ; to ordinary NPCs.
        Bed.SetFactionOwner(sharedBedFaction)
        Debug.Trace("[SyncRentBeds] Rented bed marked PlayerBedOwnership: " + Bed)
    Else
        ; Safe fallback: preserve vanilla behaviour if the faction cannot be resolved.
        Bed.SetActorOwner(Game.GetPlayer().GetActorBase())
        Debug.Trace("[SyncRentBeds] WARNING: PlayerBedOwnership not found; using vanilla player ownership for " + Bed)
    EndIf

    RegisterForSingleUpdateGameTime(pQuestScript.RentHours)
    Game.GetPlayer().RemoveItem(pQuestScript.Gold, pQuestScript.RoomRentalCost.GetValueInt())

    ; Used by vanilla innkeeper dialogue to indicate that a room is currently rented.
    SetActorValue("Variable09", 1.0)

    WI.ShowPlayerRoom(self, Bed)
EndFunction

Function ClearRoom()
    ; Restore the original vanilla ownership when the rental expires or the innkeeper dies.
    Bed.SetActorOwner((self as Actor).GetActorBase())
    UnregisterForUpdateGameTime()

    ; Re-enable the normal rental dialogue state.
    SetActorValue("Variable09", 0.0)

    Debug.Trace("[SyncRentBeds] Rental expired; restored innkeeper ownership for " + Bed)
EndFunction

Event OnUpdateGameTime()
    ClearRoom()
EndEvent

Event OnDeath(Actor akKiller)
    ClearRoom()
EndEvent
