#include "PCH.h"

#include <spdlog/sinks/basic_file_sink.h>

namespace logger = SKSE::log;

namespace SyncRentBeds
{
    std::mutex g_stateLock;
    std::unordered_set<RE::FormID> g_rentedBeds;

    RE::FormID g_activeOverrideRef{ 0 };
    RE::FormID g_savedOwner{ 0 };
    bool g_savedHadOwner{ false };

    bool IsMarkedRented(RE::TESObjectREFR* a_ref)
    {
        if (!a_ref) {
            return false;
        }

        std::scoped_lock lock(g_stateLock);
        return g_rentedBeds.contains(a_ref->GetFormID());
    }

    void RestoreActiveOverride()
    {
        if (g_activeOverrideRef == 0) {
            return;
        }

        auto* ref = RE::TESForm::LookupByID<RE::TESObjectREFR>(g_activeOverrideRef);
        auto* player = RE::PlayerCharacter::GetSingleton();
        auto* playerBase = player ? player->GetActorBase() : nullptr;

        if (ref && playerBase) {
            auto* currentOwner = ref->GetOwner();

            // Restore only if our temporary local owner is still present.
            // If STR or another mod changed ownership after us, do not overwrite it.
            if (currentOwner == playerBase) {
                if (g_savedHadOwner && g_savedOwner != 0) {
                    if (auto* oldOwner = RE::TESForm::LookupByID(g_savedOwner)) {
                        ref->extraList.SetOwner(oldOwner);
                        logger::debug(
                            "Restored owner {:08X} on rented bed {:08X}",
                            g_savedOwner,
                            g_activeOverrideRef);
                    }
                } else {
                    ref->extraList.RemoveByType(RE::ExtraDataType::kOwnership);
                    logger::debug(
                        "Removed temporary ownership from rented bed {:08X}",
                        g_activeOverrideRef);
                }
            }
        }

        g_activeOverrideRef = 0;
        g_savedOwner = 0;
        g_savedHadOwner = false;
    }

    void ApplyLocalCrosshairAccess(RE::TESObjectREFR* a_ref)
    {
        if (!a_ref || !IsMarkedRented(a_ref)) {
            return;
        }

        auto* player = RE::PlayerCharacter::GetSingleton();
        auto* playerBase = player ? player->GetActorBase() : nullptr;
        if (!playerBase) {
            logger::warn("Cannot apply rented-bed access: local player base unavailable");
            return;
        }

        if (g_activeOverrideRef == a_ref->GetFormID()) {
            // Refresh in case STR rewrote ownership while the bed stayed under the crosshair.
            a_ref->extraList.SetOwner(playerBase);
            return;
        }

        RestoreActiveOverride();

        auto* oldOwner = a_ref->GetOwner();
        g_savedHadOwner = oldOwner != nullptr;
        g_savedOwner = oldOwner ? oldOwner->GetFormID() : 0;
        g_activeOverrideRef = a_ref->GetFormID();

        a_ref->extraList.SetOwner(playerBase);

        logger::info(
            "Temporarily granted local access to rented bed {:08X}; previous owner={:08X}",
            g_activeOverrideRef,
            g_savedOwner);
    }

    void MarkRentedBed(RE::StaticFunctionTag*, RE::TESObjectREFR* a_bed)
    {
        if (!a_bed) {
            return;
        }

        {
            std::scoped_lock lock(g_stateLock);
            g_rentedBeds.insert(a_bed->GetFormID());
        }

        logger::info("Marked rented bed {:08X}", a_bed->GetFormID());

        // If this bed is already under the crosshair when Papyrus detects the rental,
        // the crosshair event may not fire again. Apply immediately when possible.
        if (auto* crosshair = RE::CrosshairPickData::GetSingleton()) {
            auto target = crosshair->target.get();
            if (target && target.get() == a_bed) {
                ApplyLocalCrosshairAccess(a_bed);
            }
        }
    }

    void ClearRentedBed(RE::StaticFunctionTag*, RE::TESObjectREFR* a_bed)
    {
        if (!a_bed) {
            return;
        }

        {
            std::scoped_lock lock(g_stateLock);
            g_rentedBeds.erase(a_bed->GetFormID());
        }

        if (g_activeOverrideRef == a_bed->GetFormID()) {
            RestoreActiveOverride();
        }

        logger::info("Cleared rented bed {:08X}", a_bed->GetFormID());
    }

    bool RegisterPapyrus(RE::BSScript::IVirtualMachine* a_vm)
    {
        if (!a_vm) {
            return false;
        }

        a_vm->RegisterFunction("MarkRentedBed", "SyncRentBedsNative", MarkRentedBed);
        a_vm->RegisterFunction("ClearRentedBed", "SyncRentBedsNative", ClearRentedBed);

        logger::info("Papyrus native bridge registered");
        return true;
    }

    class CrosshairWatcher final : public RE::BSTEventSink<SKSE::CrosshairRefEvent>
    {
    public:
        static CrosshairWatcher* GetSingleton()
        {
            static CrosshairWatcher singleton;
            return std::addressof(singleton);
        }

        RE::BSEventNotifyControl ProcessEvent(
            const SKSE::CrosshairRefEvent* a_event,
            RE::BSTEventSource<SKSE::CrosshairRefEvent>*) override
        {
            RestoreActiveOverride();

            if (a_event && a_event->crosshairRef) {
                ApplyLocalCrosshairAccess(a_event->crosshairRef.get());
            }

            return RE::BSEventNotifyControl::kContinue;
        }
    };

    class ActivateWatcher final : public RE::BSTEventSink<RE::TESActivateEvent>
    {
    public:
        static ActivateWatcher* GetSingleton()
        {
            static ActivateWatcher singleton;
            return std::addressof(singleton);
        }

        RE::BSEventNotifyControl ProcessEvent(
            const RE::TESActivateEvent* a_event,
            RE::BSTEventSource<RE::TESActivateEvent>*) override
        {
            if (!a_event || !a_event->objectActivated || !a_event->actionRef) {
                return RE::BSEventNotifyControl::kContinue;
            }

            auto* player = RE::PlayerCharacter::GetSingleton();
            if (player && a_event->actionRef.get() == player && IsMarkedRented(a_event->objectActivated.get())) {
                logger::info(
                    "Local player activation event observed for rented bed {:08X}",
                    a_event->objectActivated->GetFormID());
            }

            return RE::BSEventNotifyControl::kContinue;
        }
    };

    void RegisterEventSinks()
    {
        if (auto* crosshairSource = SKSE::GetCrosshairRefEventSource()) {
            crosshairSource->AddEventSink(CrosshairWatcher::GetSingleton());
            logger::info("Crosshair watcher registered");
        } else {
            logger::error("Crosshair event source unavailable");
        }

        if (auto* holder = RE::ScriptEventSourceHolder::GetSingleton()) {
            holder->AddEventSink<RE::TESActivateEvent>(ActivateWatcher::GetSingleton());
            logger::info("Activation watcher registered");
        } else {
            logger::error("ScriptEventSourceHolder unavailable");
        }
    }

    void MessageHandler(SKSE::MessagingInterface::Message* a_message)
    {
        if (!a_message) {
            return;
        }

        switch (a_message->type) {
        case SKSE::MessagingInterface::kDataLoaded:
            RegisterEventSinks();
            break;

        case SKSE::MessagingInterface::kPreLoadGame:
        case SKSE::MessagingInterface::kNewGame:
            RestoreActiveOverride();
            {
                std::scoped_lock lock(g_stateLock);
                g_rentedBeds.clear();
            }
            break;

        default:
            break;
        }
    }
}

SKSEPluginLoad(const SKSE::LoadInterface* a_skse)
{
    SKSE::Init(a_skse);

    auto path = logger::log_directory();
    if (path) {
        *path /= "SyncRentBeds.log";
        auto sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>(path->string(), true);
        auto log = std::make_shared<spdlog::logger>("global log", std::move(sink));
        log->set_level(spdlog::level::debug);
        log->flush_on(spdlog::level::info);
        spdlog::set_default_logger(std::move(log));
    }

    logger::info("SyncRentBeds v{} loading", SYNC_RENT_BEDS_VERSION);

    auto* papyrus = SKSE::GetPapyrusInterface();
    if (!papyrus || !papyrus->Register(SyncRentBeds::RegisterPapyrus)) {
        logger::critical("Failed to register Papyrus native functions");
        return false;
    }

    auto* messaging = SKSE::GetMessagingInterface();
    if (!messaging || !messaging->RegisterListener(SyncRentBeds::MessageHandler)) {
        logger::critical("Failed to register SKSE messaging listener");
        return false;
    }

    return true;
}
