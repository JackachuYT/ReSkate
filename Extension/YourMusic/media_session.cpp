// C++/WinRT first, at warning level 3: the SDK's projection headers are not /W4-clean everywhere.
#pragma warning(push, 3)
#include <unknwn.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Media.Control.h>
#pragma warning(pop)

#include "media_session.h"
#include "media_session_choice.h"
#include "Engine/Core/Json/json.h"
#include "Engine/Core/Log/logging.h"
#include "Extension/UI/Overlay/overlay.h"

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <deque>
#include <mutex>
#include <optional>
#include <thread>
#include <vector>

namespace dingosdk::your_music {
namespace {
using namespace std::chrono_literals;
using Manager = winrt::Windows::Media::Control::GlobalSystemMediaTransportControlsSessionManager;
using Session = winrt::Windows::Media::Control::GlobalSystemMediaTransportControlsSession;
using Status = winrt::Windows::Media::Control::GlobalSystemMediaTransportControlsSessionPlaybackStatus;

std::once_flag started;
std::mutex mutex;
std::condition_variable wake;
std::deque<MediaCommand> commands; // guarded by mutex
NowPlaying latest;                 // guarded by mutex
std::atomic<bool> active{}, popups{true};

void log_event(const Json& event) {
    dingosdk::logging::event(dingosdk::logging::Channel::music, event.dump());
}

const char* command_name(MediaCommand command) {
    switch (command) {
    case MediaCommand::play: return "play";
    case MediaCommand::pause: return "pause";
    case MediaCommand::next: return "next";
    }
    return "unknown";
}

Session choose(const Manager& manager) {
    const auto sessions = manager.GetSessions();
    std::vector<std::string> ids;
    ids.reserve(sessions.Size());
    for (const auto& session : sessions) ids.push_back(winrt::to_string(session.SourceAppUserModelId()));
    std::optional<std::size_t> current;
    if (const auto session = manager.GetCurrentSession()) {
        const auto id = winrt::to_string(session.SourceAppUserModelId());
        for (std::size_t i = 0; i < ids.size() && !current; ++i)
            if (ids[i] == id) current = i;
    }
    const auto index = choose_session(ids, current);
    if (index == no_session) return nullptr;
    return sessions.GetAt(static_cast<std::uint32_t>(index));
}

void send(const Session& session, MediaCommand command) {
    bool accepted = false;
    switch (command) {
    case MediaCommand::play: accepted = session.TryPlayAsync().get(); break;
    case MediaCommand::pause: accepted = session.TryPauseAsync().get(); break;
    case MediaCommand::next: accepted = session.TrySkipNextAsync().get(); break;
    }
    log_event(Json{{"event", "your_music_command"}, {"command", command_name(command)},
        {"app", winrt::to_string(session.SourceAppUserModelId())}, {"accepted", accepted}});
}

NowPlaying read(const Session& session) {
    NowPlaying now;
    if (!session) return now;
    now.app = app_display_name(winrt::to_string(session.SourceAppUserModelId()));
    if (const auto properties = session.TryGetMediaPropertiesAsync().get()) {
        now.title = winrt::to_string(properties.Title());
        now.artist = winrt::to_string(properties.Artist());
    }
    now.playing = session.GetPlaybackInfo().PlaybackStatus() == Status::Playing;
    return now;
}

void worker() noexcept {
    try {
        winrt::init_apartment(winrt::apartment_type::multi_threaded);
        const auto manager = Manager::RequestAsync().get();
        log_event(Json{{"event", "your_music_media_ready"}});
        std::string shown; // the song last shown in a pop-up; cleared while Your Music is off
        int failures = 0;
        for (;;) {
            std::optional<MediaCommand> command;
            {
                std::unique_lock lock(mutex);
                wake.wait_for(lock, 500ms, [] { return !commands.empty(); });
                if (!commands.empty()) {
                    command = commands.front();
                    commands.pop_front();
                }
            }
            try {
                const auto session = choose(manager);
                if (command && session) send(session, *command);
                else if (command && *command == MediaCommand::play)
                    dingosdk::overlay::notify(dingosdk::overlay::NoticeLevel::warning, "Your Music",
                        "Open Spotify or Apple Music and start a song, then pick Your Music again.");
                auto now = read(session);
                if (!active.load(std::memory_order_acquire)) shown.clear();
                else if (const auto key = now.app + '\n' + now.title + '\n' + now.artist;
                         !now.title.empty() && key != shown) {
                    shown = key;
                    if (popups.load(std::memory_order_acquire))
                        dingosdk::overlay::notify(dingosdk::overlay::NoticeLevel::info, now.title,
                            now.artist.empty() ? now.app : now.artist + "  -  " + now.app);
                }
                std::lock_guard lock(mutex);
                latest = std::move(now);
                failures = 0;
            } catch (const winrt::hresult_error& error) {
                // Apps come and go mid-call; log the first few in a row, then stay quiet.
                if (++failures <= 3)
                    log_event(Json{{"event", "your_music_media_error"}, {"hresult", static_cast<std::int64_t>(error.code().value)},
                        {"message", winrt::to_string(error.message())}});
            }
        }
    } catch (...) {
        log_event(Json{{"event", "your_music_media_unavailable"}});
    }
}
} // namespace

void start_media_session() noexcept {
    try {
        std::call_once(started, [] { std::thread(worker).detach(); });
    } catch (...) {
        log_event(Json{{"event", "your_music_media_thread_failed"}});
    }
}

void send_media_command(MediaCommand command) noexcept {
    try {
        {
            std::lock_guard lock(mutex);
            commands.push_back(command);
        }
        wake.notify_one();
    } catch (...) {
    }
}

void set_media_active(bool value) noexcept { active.store(value, std::memory_order_release); }

NowPlaying media_now_playing() {
    std::lock_guard lock(mutex);
    return latest;
}

void set_media_popups(bool enabled) noexcept { popups.store(enabled, std::memory_order_release); }
bool media_popups() noexcept { return popups.load(std::memory_order_acquire); }
} // namespace dingosdk::your_music
