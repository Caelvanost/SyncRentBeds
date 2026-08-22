Scriptname RentRoomScript extends Actor Conditional
{STR-friendly replacement for the vanilla inn room rental script.}

ObjectReference Property Bed Auto
{Bed rented by this innkeeper.}

WIFunctionsScript Property WI Auto
{Pointer to WIFunctionsScript attached to the WI quest.}

Float Property SyncPollSeconds = 2.0 Auto Hidden

Function ApplyLocalRentalState()
    If Bed == None
        Return
    EndIf

    If GetActorValue("Variable09") >= 1.0
        ; STR appears to synchronize the innkeeper rental state but not the
        ; bed's ownership. Rebuild that ownership independently on each client
        ; so the local player can use the shared rented bed.
        Bed.SetActorOwner(Game.GetPlayer().GetActorBase())
        Debug.Trace("[SyncRentBeds] Applied rented bed ownership to local player: " + Bed)
    Else
        ; Keep the normal innkeeper ownership whenever the room is not rented.
        Bed.SetActorOwner((self as Actor).GetActorBase())
    EndIf
EndFunction

Function StartLocalSync()
    ApplyLocalRentalState()
    RegisterForSingleUpdate(SyncPollSeconds)
EndFunction

Function RentRoom(DialogueGenericScript pQuestScript)
    Debug.Trace("[SyncRentBeds] RentRoom intercepted")

    ; Vanilla behaviour on the client that performs the rental.
    Bed.SetActorOwner(Game.GetPlayer().GetActorBase())
    RegisterForSingleUpdateGameTime(pQuestScript.RentHours)
    Game.GetPlayer().RemoveItem(pQuestScript.Gold, pQuestScript.RoomRentalCost.GetValueInt())

    ; This is the vanilla state used to conditionalize innkeeper dialogue.
    ; STR already appears to replicate it between clients, so other clients
    ; use it as the source of truth for rebuilding local bed ownership.
    SetActorValue("Variable09", 1.0)

    WI.ShowPlayerRoom(self, Bed)

    StartLocalSync()
EndFunction

Function ClearRoom()
    Bed.SetActorOwner((self as Actor).GetActorBase())
    UnregisterForUpdateGameTime()
    SetActorValue("Variable09", 0.0)

    Debug.Trace("[SyncRentBeds] Rental expired; restored innkeeper ownership for " + Bed)
EndFunction

Event OnCellAttach()
    Debug.Trace("[SyncRentBeds] Innkeeper cell attached; starting local rental sync")
    StartLocalSync()
EndEvent

Event OnCellDetach()
    UnregisterForUpdate()
    Debug.Trace("[SyncRentBeds] Innkeeper cell detached; stopped local rental sync")
EndEvent

Event OnUpdate()
    ApplyLocalRentalState()
    RegisterForSingleUpdate(SyncPollSeconds)
EndEvent

Event OnUpdateGameTime()
    ClearRoom()
EndEvent

Event OnDeath(Actor akKiller)
    ClearRoom()
    UnregisterForUpdate()
EndEvent
