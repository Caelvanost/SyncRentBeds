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

Function ObserveRentalState(String reason = "poll")
    If Bed == None
        Return
    EndIf

    Float rentalState = GetActorValue("Variable09")

    If rentalState >= 1.0
        ConsecutiveZeroPolls = 0

        If !RentalLatched
            RentalLatched = True
            SyncRentBedsNative.MarkRentedBed(Bed)
            Debug.Trace("[SyncRentBeds] Rental latched and native bed marker enabled. reason=" + reason + " Variable09=" + rentalState + " Bed=" + Bed)
        EndIf
    ElseIf RentalLatched
        ConsecutiveZeroPolls += 1
        Debug.Trace("[SyncRentBeds] Ignoring transient Variable09=0 while latched. reason=" + reason + " zeroPolls=" + ConsecutiveZeroPolls + "/" + ZeroPollsToRelease + " Bed=" + Bed)

        If ConsecutiveZeroPolls >= ZeroPollsToRelease
            RentalLatched = False
            ConsecutiveZeroPolls = 0
            SyncRentBedsNative.ClearRentedBed(Bed)
            Debug.Trace("[SyncRentBeds] Rental latch released and native bed marker cleared. Bed=" + Bed)
        EndIf
    EndIf
EndFunction

Function StartLocalSync(String reason = "start")
    ObserveRentalState(reason)
    RegisterForSingleUpdate(SyncPollSeconds)
EndFunction

Function RentRoom(DialogueGenericScript pQuestScript)
    Debug.Trace("[SyncRentBeds] RentRoom intercepted")

    RentalLatched = True
    ConsecutiveZeroPolls = 0

    ; Preserve Bethesda's normal ownership on the client that actually rents.
    Bed.SetActorOwner(Game.GetPlayer().GetActorBase())
    SyncRentBedsNative.MarkRentedBed(Bed)

    RegisterForSingleUpdateGameTime(pQuestScript.RentHours)
    Game.GetPlayer().RemoveItem(pQuestScript.Gold, pQuestScript.RoomRentalCost.GetValueInt())

    SetActorValue("Variable09", 1.0)

    WI.ShowPlayerRoom(self, Bed)

    StartLocalSync("RentRoom")
EndFunction

Function ClearRoom()
    RentalLatched = False
    ConsecutiveZeroPolls = 0

    SyncRentBedsNative.ClearRentedBed(Bed)

    ; Preserve vanilla cleanup on the client that owns the rental timer.
    Bed.SetActorOwner((self as Actor).GetActorBase())
    UnregisterForUpdateGameTime()
    SetActorValue("Variable09", 0.0)

    Debug.Trace("[SyncRentBeds] Rental expired locally; native bed marker cleared for " + Bed)
EndFunction

Event OnCellAttach()
    Debug.Trace("[SyncRentBeds] Innkeeper cell attached; starting rental-state observation")
    StartLocalSync("OnCellAttach")
EndEvent

Event OnCellDetach()
    UnregisterForUpdate()
    SyncRentBedsNative.ClearRentedBed(Bed)
    RentalLatched = False
    ConsecutiveZeroPolls = 0
    Debug.Trace("[SyncRentBeds] Innkeeper cell detached; stopped observation and cleared native marker")
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
