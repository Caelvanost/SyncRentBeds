Scriptname RentRoomScript extends Actor Conditional
{STR-friendly replacement for the vanilla inn room rental script.}

ObjectReference Property Bed Auto
{Bed rented by this innkeeper.}

WIFunctionsScript Property WI Auto
{Pointer to WIFunctionsScript attached to the WI quest.}

Float Property SyncPollSeconds = 2.0 Auto Hidden

Function DebugLocalState(String reason)
    Float rentalState = GetActorValue("Variable09")
    String debugText = "SyncRentBeds 0.1.3 [" + reason + "] Variable09=" + rentalState + " Bed=" + Bed
    Debug.Notification(debugText)
    Debug.Trace("[SyncRentBeds] " + debugText)
EndFunction

Function ApplyLocalRentalState(String reason = "poll")
    If Bed == None
        Debug.Trace("[SyncRentBeds] ApplyLocalRentalState skipped: Bed is None")
        Return
    EndIf

    Float rentalState = GetActorValue("Variable09")

    If rentalState >= 1.0
        Bed.SetActorOwner(Game.GetPlayer().GetActorBase())
        Debug.Trace("[SyncRentBeds] Applied rented bed ownership to local player. reason=" + reason + " Variable09=" + rentalState + " Bed=" + Bed)
    Else
        Bed.SetActorOwner((self as Actor).GetActorBase())
        Debug.Trace("[SyncRentBeds] Restored/kept innkeeper ownership locally. reason=" + reason + " Variable09=" + rentalState + " Bed=" + Bed)
    EndIf
EndFunction

Function StartLocalSync(String reason = "start")
    DebugLocalState(reason)
    ApplyLocalRentalState(reason)
    RegisterForSingleUpdate(SyncPollSeconds)
EndFunction

Function RentRoom(DialogueGenericScript pQuestScript)
    Debug.Notification("SyncRentBeds 0.1.3: RentRoom intercepted")
    Debug.Trace("[SyncRentBeds] RentRoom intercepted")

    Bed.SetActorOwner(Game.GetPlayer().GetActorBase())
    RegisterForSingleUpdateGameTime(pQuestScript.RentHours)
    Game.GetPlayer().RemoveItem(pQuestScript.Gold, pQuestScript.RoomRentalCost.GetValueInt())

    SetActorValue("Variable09", 1.0)

    WI.ShowPlayerRoom(self, Bed)

    StartLocalSync("RentRoom")
EndFunction

Function ClearRoom()
    Bed.SetActorOwner((self as Actor).GetActorBase())
    UnregisterForUpdateGameTime()
    SetActorValue("Variable09", 0.0)

    Debug.Trace("[SyncRentBeds] Rental expired; restored innkeeper ownership for " + Bed)
EndFunction

Event OnCellAttach()
    Debug.Notification("SyncRentBeds 0.1.3: OnCellAttach")
    Debug.Trace("[SyncRentBeds] Innkeeper cell attached; starting local rental sync")
    StartLocalSync("OnCellAttach")
EndEvent

Event OnCellDetach()
    UnregisterForUpdate()
    Debug.Trace("[SyncRentBeds] Innkeeper cell detached; stopped local rental sync")
EndEvent

Event OnUpdate()
    DebugLocalState("OnUpdate")
    ApplyLocalRentalState("OnUpdate")
    RegisterForSingleUpdate(SyncPollSeconds)
EndEvent

Event OnUpdateGameTime()
    ClearRoom()
EndEvent

Event OnDeath(Actor akKiller)
    ClearRoom()
    UnregisterForUpdate()
EndEvent
