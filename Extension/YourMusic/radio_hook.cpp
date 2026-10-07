#include "radio_hook.h"
#include "handoff_policy.h"
#include "media_session.h"
#include "Engine/Core/Json/json.h"
#include "Engine/Core/Log/logging.h"
#include "Engine/Core/Platform/memory.h"
#include "Engine/Game/Build/addresses.h"
#include "Engine/Game/Build/20260929/local_music.h"
#include "Extension/Customization/local_customization_runtime.h"
#include "Extension/Music/local_music_assets.h"

#include <Windows.h>
#include <chrono>
#include <mutex>
#include <string>

namespace dingosdk::your_music {
namespace {
std::mutex mutex;
RadioState state; // guarded by mutex

std::uint64_t now_ms() noexcept {
    return static_cast<std::uint64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count());
}

struct QueueLock {
    explicit QueueLock(std::uintptr_t queue) noexcept
        : section(reinterpret_cast<LPCRITICAL_SECTION>(queue + 0x150)) { EnterCriticalSection(section); }
    ~QueueLock() { LeaveCriticalSection(section); }
    QueueLock(const QueueLock&) = delete;
    QueueLock& operator=(const QueueLock&) = delete;
    LPCRITICAL_SECTION section;
};

// "artist - title" of the song at candidate `index`, as the game registers it. The layouts are
// the ones local_music_playback.cpp (current_guid) and local_music_assets.cpp already read.
bool song_id_at(std::uintptr_t queue, std::uintptr_t playlist_asset, std::int32_t index, std::string& id) noexcept {
    using dingosdk::memory::peek;
    using profile_runtime::music_asset_type;
    std::uintptr_t begin{}, end{}, entries{};
    std::uint32_t asset_index{}, encoded_count{};
    {
        QueueLock lock(queue);
        if (!peek(queue + 0x78, begin) || !peek(queue + 0x80, end) || end < begin || (end - begin) % 4 ||
            static_cast<std::uint64_t>(index) >= (end - begin) / 4 ||
            !peek(begin + static_cast<std::uintptr_t>(index) * 4, asset_index)) return false;
    }
    if (!peek(playlist_asset + 0x60, entries) || !entries || !peek(entries - 4, encoded_count) ||
        asset_index >= (encoded_count & 0x7fffffffu)) return false;
    std::uintptr_t graph{}, metadata{}, artist{}, title{};
    if (!peek(entries + static_cast<std::uintptr_t>(asset_index) * 8, graph)) return false;
    graph &= ~std::uintptr_t{4};
    if (!music_asset_type(graph, addr::local_music::graph_asset_vtable) || !peek(graph + 0x20, metadata)) return false;
    metadata &= ~std::uintptr_t{4};
    if (!music_asset_type(metadata, addr::local_music::metadata_vtable) ||
        !peek(metadata + 0x18, artist) || !peek(metadata + 0x20, title)) return false;
    std::string artist_text, title_text;
    if (!profile_runtime::cosmetic_text(artist, artist_text) || !profile_runtime::cosmetic_text(title, title_text))
        return false;
    id = artist_text + " - " + title_text;
    return true;
}
} // namespace

void on_radio_select(std::uintptr_t queue, std::uintptr_t playlist_asset, std::int32_t selected) noexcept {
    try {
        std::string id;
        const bool known = queue && playlist_asset && selected >= 0 && song_id_at(queue, playlist_asset, selected, id);
        // Diagnostic for the in-game tests: every pick, so a log shows what the radio did.
        dingosdk::logging::event(dingosdk::logging::Channel::music,
            Json{{"event", "your_music_select"}, {"selected", selected}, {"known", known}, {"song", id}}.dump());
        if (!known) return; // cannot tell what is playing: change nothing

        Command command{};
        {
            std::lock_guard lock(mutex);
            const auto decision = on_select(state, id == placeholder_song_id, now_ms());
            state = decision.state;
            command = decision.command;
            set_media_active(state.active);
        }
        switch (command) {
        case Command::play: send_media_command(MediaCommand::play); break;
        case Command::pause: send_media_command(MediaCommand::pause); break;
        case Command::next: send_media_command(MediaCommand::next); break;
        case Command::none: break;
        }
    } catch (...) {
    }
}

void radio_before_level_transition() noexcept {
    std::lock_guard lock(mutex);
    state = {};
    set_media_active(false);
}
} // namespace dingosdk::your_music
