#include "Extension/YourMusic/media_session_choice.h"
#include <cstdio>

namespace ym = dingosdk::your_music;

int main() {
    int failures = 0;
    const auto check = [&](bool ok, const char* message) {
        if (!ok) { std::printf("FAIL: %s\n", message); ++failures; }
    };
    const std::string spotify_desktop = "Spotify.exe";
    const std::string spotify_store = "SpotifyAB.SpotifyMusic_zpdnekdrzrea0!Spotify";
    const std::string apple = "AppleInc.AppleMusicWin_nzyj5cx40ttqa!App";
    const std::string edge = "MSEdge";
    const std::string chrome = "Chrome";

    check(ym::session_rank(spotify_desktop) == 0 && ym::session_rank(spotify_store) == 0, "Spotify ranks first");
    check(ym::session_rank(apple) == 1, "Apple Music ranks second");
    check(ym::session_rank(edge) == 2, "other apps rank last");

    check(ym::app_display_name(spotify_store) == "Spotify", "Spotify's store id shows as Spotify");
    check(ym::app_display_name(apple) == "Apple Music", "Apple Music's id shows as Apple Music");
    check(ym::app_display_name("vlc.exe") == "vlc", "an exe id shows without .exe");
    check(ym::app_display_name("Contoso.Player_abc123!App") == "Contoso.Player", "a store id shows its package name");

    check(ym::choose_session({}, std::nullopt) == ym::no_session, "no sessions, nothing to control");
    check(ym::choose_session({edge, apple, spotify_desktop}, 0) == 2, "Spotify wins even when another app is current");
    check(ym::choose_session({edge, apple}, 0) == 1, "Apple Music wins over a browser");
    check(ym::choose_session({edge, chrome}, 1) == 1, "among other apps, the system's current one wins");
    check(ym::choose_session({edge, chrome}, std::nullopt) == 0, "among other apps with none current, the first wins");

    std::printf(failures ? "%d failure(s)\n" : "all passed\n", failures);
    return failures ? 1 : 0;
}
