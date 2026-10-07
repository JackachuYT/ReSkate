#pragma once

#include <cstdint>
#include <string_view>

// Watches the songs skate.'s radio picks and hands off to the player's music app when it picks
// the Your Music placeholder (Mods\YourMusic, built by ReSkateMusicPacker).
namespace dingosdk::your_music {
inline constexpr std::string_view placeholder_song_id = "Your Music - Playing from your app";

// Called from the radio's select-next hook after the native selector returns `selected`, an index
// into the queue's candidate list (-1 when it picked nothing).
void on_radio_select(std::uintptr_t queue, std::uintptr_t playlist_asset, std::int32_t selected) noexcept;
// A map change restarts the radio: the next placeholder pick resumes the app instead of skipping.
void radio_before_level_transition() noexcept;
} // namespace dingosdk::your_music
