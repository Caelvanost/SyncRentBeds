Scriptname RentRoomScript extends Actor Conditional
{STR-friendly replacement for the vanilla inn room rental script.}

ObjectReference Property Bed Auto
{Bed rented by this innkeeper.}

WIFunctionsScript Property WI Auto
{Pointer to WIFunctionsScript attached to the WI quest.}

Float Property SyncPollSeconds = 2.0 Auto Hidden
Int Property ZeroPollsToRelease = 15 Auto Hidden

Bool RentalLatched = False
Int ConsecutiveZeroPolls = 0

Function ApplyLocalOwnership(String reason = "poll")
    If Bed == None
        Debug.Trace("[SyncRentBeds] ApplyLocalOwnership skipped: Bed is None")
        Return
    EndIf

    If RentalLatched
        Bed.SetActorOwner(Game.GetPlayer().GetActorBase())
        Debug.Trace("[SyncRentBeds] Local rented-bed ownership applied. reason=" + reason + " Bed=" + Bed)
    Else
        Bed.SetActorOwner((self as Actor).GetActorBase())
        Debug.Trace("[SyncRentBeds] Innkeeper ownership applied. reason=" + reason + " Bed=" + Bed)
    EndIf
EndFunction

Function ObserveRentalState(String reason = "poll")
    Float rentalState = GetActorValue("Variable09")

    If rentalState >= 1.0
        ConsecutiveZeroPolls = 0

        If !RentalLatched
            RentalLatched = True
            Debug.Notification("SyncRentBeds 0.1.5: shared rental detected")
            Debug.Trace("[SyncRentBeds] Rental latched locally. reason=" + reason + " Variable09=" + rentalState + " Bed=" + Bed)
        EndIf
    ElseIf RentalLatched
        ConsecutiveZeroPolls += 1
        Debug.Trace("[SyncRentBeds] Ignoring transient Variable09=0 while latched. reason=" + reason + " zeroPolls=" + ConsecutiveZeroPolls + "/" + ZeroPollsToRelease + " Bed=" + Bed)

        If ConsecutiveZeroPolls >= ZeroPollsToRelease
            RentalLatched = False
            ConsecutiveZeroPolls = 0
            Debug.Notification("SyncRentBeds 0.1.5: shared rental released")
            Debug.Trace("[SyncRentBeds] Rental latch released after sustained Variable09=0. Bed=" + Bed)
        EndIf
    EndIf

    ApplyLocalOwnership(reason)
EndFunction

Function StartLocalSync(String reason = "start")
    ObserveRentalState(reason)
    RegisterForSingleUpdate(SyncPollSeconds)
EndFunction

Function RentRoom(DialogueGenericScript pQuestScript)
    Debug.Notification("SyncRentBeds 0.1.5: RentRoom intercepted")
    Debug.Trace("[SyncRentBeds] RentRoom intercepted")

    RentalLatched = True
    ConsecutiveZeroPolls = 0

    Bed.SetActorOwner(Game.GetPlayer().GetActorBase())
    RegisterForSingleUpdateGameTime(pQuestScript.RentHours)
    Game.GetPlayer().RemoveItem(pQuestScript.Gold, pQuestScript.RoomRentalCost.GetValueInt())

    SetActorValue("Variable09", 1.0)

    WI.ShowPlayerRoom(self, Bed)

    StartLocalSync("RentRoom")
EndFunction

Function ClearRoom()
    RentalLatched = False
    ConsecutiveZeroPolls = 0

    Bed.SetActorOwner((self as Actor).GetActorBase())
    UnregisterForUpdateGameTime()
    SetActorValue("Variable09", 0.0)

    Debug.Trace("[SyncRentBeds] Rental expired locally; latch cleared and innkeeper ownership restored for " + Bed)
EndFunction

Event OnCellAttach()
    Debug.Trace("[SyncRentBeds] Innkeeper cell attached; starting local rental sync")
    StartLocalSync("OnCellAttach")
EndEvent

Event OnCellDetach()
    UnregisterForUpdate()
    Debug.Trace("[SyncRentBeds] Innkeeper cell detached; stopped local rental polling")
EndEvent

Event OnUpdate()
    ObserveRentalState("OnUpdate")
    RegisterForSingleUpdate(SyncPollSeconds)
EndEvent

Event OnUpdateGameTime()
    ClearRoom()
EndEvent

Event OnDeath(Actor akKiller)
    ClearRoom()
    UnregisterForUpdate()
EndEvent
