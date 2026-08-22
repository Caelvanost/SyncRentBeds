#include "PCH.h"

#include <spdlog/sinks/basic_file_sink.h>

namespace logger = SKSE::log;

namespace SyncRentBeds
{
    constexpr RE::FormID kPlayerBedOwnershipFormID = 0x000F2073;

    std::atomic_bool g_retryActivation{ false };

    RE::TESFaction* GetPlayerBedOwnershipFaction()
    {
        return RE::TESForm::LookupByID<RE::TESFaction>(kPlayerBedOwnershipFormID);
    }

    bool IsSharedRentedBed(RE::TESObjectREFR* target)
    {
        if (!target) {
            return false;
        }

        auto* base = target->GetBaseObject();
        if (!base || base->GetFormType() != RE::FormType::Furniture) {
            return false;
        }

        auto* sharedOwner = GetPlayerBedOwnershipFaction();
        return sharedOwner && target->GetOwner() == sharedOwner;
    }

    void RetryActivation(const RE::ObjectRefHandle& handle)
    {
        RE::NiPointer<RE::TESObjectREFR> target;
        if (!RE::LookupReferenceByHandle(handle, target) || !target) {
            logger::warn("Rented bed vanished before retry activation");
            return;
        }

        auto* player = RE::PlayerCharacter::GetSingleton();
        auto* sharedOwner = GetPlayerBedOwnershipFaction();
        if (!player || !sharedOwner || !IsSharedRentedBed(target.get())) {
            return;
        }

        auto* playerBase = player->GetActorBase();
        if (!playerBase) {
            logger::error("Local player ActorBase unavailable");
            return;
        }

        // Local-only, one-shot ownership substitution. We deliberately touch
        // only ExtraOwnership and do not mark the reference changed, so this
        // temporary bypass is not persisted or propagated through STR.
        target->extraList.SetOwner(playerBase);

        g_retryActivation.store(true, std::memory_order_release);
        const bool activated = target->ActivateRef(player, 0, nullptr, 1, false);
        g_retryActivation.store(false, std::memory_order_release);

        // Restore the marker immediately so NPC ownership rules remain intact.
        target->extraList.SetOwner(sharedOwner);

        logger::info(
            "Retried local activation for rented furniture {:08X}: {}",
            target->GetFormID(),
            activated ? "success" : "failed");
    }

    class ActivateWatcher final : public RE::BSTEventSink<RE::TESActivateEvent>
    {
    public:
        static ActivateWatcher* GetSingleton()
        {
            static ActivateWatcher singleton;
            return std::addressof(singleton);
        }

        RE::BSEventNotifyControl ProcessEvent(
            const RE::TESActivateEvent* event,
            RE::BSTEventSource<RE::TESActivateEvent>*) override
        {
            if (!event || g_retryActivation.load(std::memory_order_acquire)) {
                return RE::BSEventNotifyControl::kContinue;
            }

            auto* player = RE::PlayerCharacter::GetSingleton();
            auto* activator = event->actionRef.get();
            auto* target = event->objectActivated.get();

            if (!player || activator != player || !IsSharedRentedBed(target)) {
                return RE::BSEventNotifyControl::kContinue;
            }

            const auto handle = target->CreateRefHandle();
            logger::info(
                "Local player activated shared rented furniture {:08X}; scheduling ownership bypass",
                target->GetFormID());

            if (auto* tasks = SKSE::GetTaskInterface()) {
                tasks->AddTask([handle]() {
                    RetryActivation(handle);
                });
            } else {
                logger::warn("SKSE task interface unavailable; retrying activation immediately");
                RetryActivation(handle);
            }

            return RE::BSEventNotifyControl::kContinue;
        }
    };

    void RegisterActivateWatcher()
    {
        auto* holder = RE::ScriptEventSourceHolder::GetSingleton();
        if (!holder) {
            logger::critical("ScriptEventSourceHolder unavailable");
            return;
        }

        holder->GetEventSource<RE::TESActivateEvent>()->AddEventSink(ActivateWatcher::GetSingleton());
        logger::info("TESActivateEvent watcher registered");
    }

    void MessageHandler(SKSE::MessagingInterface::Message* message)
    {
        if (!message) {
            return;
        }

        if (message->type == SKSE::MessagingInterface::kDataLoaded) {
            auto* faction = GetPlayerBedOwnershipFaction();
            if (!faction) {
                logger::critical("PlayerBedOwnership [000F2073] could not be resolved");
                return;
            }

            logger::info("PlayerBedOwnership resolved: {:08X}", faction->GetFormID());
            RegisterActivateWatcher();
        }
    }
}

SKSEPluginLoad(const SKSE::LoadInterface* skse)
{
    SKSE::Init(skse);

    auto path = logger::log_directory();
    if (path) {
        *path /= "SyncRentBeds.log";
        auto sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>(path->string(), true);
        auto log = std::make_shared<spdlog::logger>("global log", std::move(sink));
        log->set_level(spdlog::level::info);
        log->flush_on(spdlog::level::info);
        spdlog::set_default_logger(std::move(log));
    }

    logger::info("SyncRentBeds v{} loading", SYNC_RENT_BEDS_VERSION);

    auto* messaging = SKSE::GetMessagingInterface();
    if (!messaging || !messaging->RegisterListener(SyncRentBeds::MessageHandler)) {
        logger::critical("Failed to register SKSE messaging listener");
        return false;
    }

    return true;
}
