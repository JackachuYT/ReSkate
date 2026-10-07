#include "Extension/YourMusic/handoff_policy.h"
#include <cstdio>

namespace ym = dingosdk::your_music;

int main() {
    int failures = 0;
    const auto check = [&](bool ok, const char* message) {
        if (!ok) { std::printf("FAIL: %s\n", message); ++failures; }
    };

    auto d = ym::on_select({}, true, 5'000);
    check(d.command == ym::Command::play && d.state.active && d.state.started_ms == 5'000,
          "switching onto Your Music plays the app and starts the placeholder clock");

    d = ym::on_select({}, false, 5'000);
    check(d.command == ym::Command::none && !d.state.active,
          "a game song while Your Music is off changes nothing");

    d = ym::on_select({true, 5'000}, false, 9'000);
    check(d.command == ym::Command::pause && !d.state.active,
          "switching from Your Music to a game song pauses the app");

    d = ym::on_select({true, 5'000}, true, 35'000);
    check(d.command == ym::Command::next && d.state.active && d.state.started_ms == 35'000,
          "a select-next 30 s into the placeholder is the player pressing Next");

    d = ym::on_select({true, 0}, true, ym::placeholder_length_ms - 1'000);
    check(d.command == ym::Command::none && d.state.started_ms == ym::placeholder_length_ms - 1'000,
          "the placeholder ending on its own (within the margin) only restarts the clock");

    d = ym::on_select({true, 0}, true, ym::placeholder_length_ms + 60'000);
    check(d.command == ym::Command::none, "a late natural end is not a Next press");

    d = ym::on_select({true, 50'000}, true, 10'000);
    check(d.command == ym::Command::none && d.state.active,
          "a clock that went backwards is never treated as Next");

    d = ym::on_select({true, 0}, true, ym::placeholder_length_ms - ym::natural_end_margin_ms - 1);
    check(d.command == ym::Command::next, "just before the margin is still a Next press");

    std::printf(failures ? "%d failure(s)\n" : "all passed\n", failures);
    return failures ? 1 : 0;
}
