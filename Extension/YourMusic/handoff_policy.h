#pragma once

#include <cstdint>

// What to tell the player's music app when skate.'s radio picks a song. Pure, so it is tested
// without the game. It reacts only to transitions: it never re-sends play while the radio stays
// on Your Music, so pausing the app by hand is never overridden.
namespace dingosdk::your_music {
// The silent placeholder song in Mods\YourMusic.
inline constexpr std::uint64_t placeholder_length_ms = 1'200'000;
// A select-next on the placeholder later than this before its end is its natural end, not Next.
inline constexpr std::uint64_t natural_end_margin_ms = 2'000;

enum class Command { none, play, pause, next };

struct RadioState {
    bool active{};              // the radio is on the placeholder
    std::uint64_t started_ms{}; // steady-clock time the placeholder last started
};

struct Decision {
    Command command{};
    RadioState state{};
};

// One select-next from the game's radio; `placeholder_picked` is whether it picked the placeholder.
constexpr Decision on_select(RadioState state, bool placeholder_picked, std::uint64_t now_ms) noexcept {
    if (!placeholder_picked) return {state.active ? Command::pause : Command::none, {}};
    if (!state.active) return {Command::play, {true, now_ms}};
    const bool skipped = now_ms >= state.started_ms &&
        now_ms - state.started_ms + natural_end_margin_ms < placeholder_length_ms;
    return {skipped ? Command::next : Command::none, {true, now_ms}};
}
} // namespace dingosdk::your_music
