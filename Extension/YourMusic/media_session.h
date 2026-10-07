#pragma once

#include <string>

// The player's music app, through Windows' media controls. All Windows calls run on one worker
// thread; these functions only queue work or copy the latest snapshot, so game threads never wait.
namespace dingosdk::your_music {
enum class MediaCommand { play, pause, next };

struct NowPlaying {
    std::string app; // "Spotify", "Apple Music", another app's name; empty when no app is open
    std::string title, artist;
    bool playing{};
};

void start_media_session() noexcept;
void send_media_command(MediaCommand command) noexcept;
// Whether the radio is on Your Music. Song pop-ups only show while it is.
void set_media_active(bool active) noexcept;
NowPlaying media_now_playing();
void set_media_popups(bool enabled) noexcept;
bool media_popups() noexcept;
} // namespace dingosdk::your_music
