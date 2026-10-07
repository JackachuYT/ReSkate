#pragma once

#include <cctype>
#include <cstddef>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

// Which Windows media session Your Music controls, and what to call its app. Pure, so it is
// tested without Windows. App ids are AppUserModelIDs: "Spotify.exe" for the desktop app,
// "<package>_<publisher>!<app>" for Store apps.
namespace dingosdk::your_music {
inline constexpr std::size_t no_session = static_cast<std::size_t>(-1);

inline bool contains_folded(std::string_view text, std::string_view lower_needle) noexcept {
    if (lower_needle.size() > text.size()) return false;
    for (std::size_t i = 0; i + lower_needle.size() <= text.size(); ++i) {
        bool equal = true;
        for (std::size_t j = 0; j < lower_needle.size() && equal; ++j)
            equal = std::tolower(static_cast<unsigned char>(text[i + j])) == lower_needle[j];
        if (equal) return true;
    }
    return false;
}

// 0 Spotify, 1 Apple Music, 2 anything else.
inline int session_rank(std::string_view app_id) noexcept {
    if (contains_folded(app_id, "spotify")) return 0;
    if (contains_folded(app_id, "applemusic")) return 1;
    return 2;
}

inline std::string app_display_name(std::string_view app_id) {
    if (session_rank(app_id) == 0) return "Spotify";
    if (session_rank(app_id) == 1) return "Apple Music";
    std::string_view name = app_id;
    if (const auto underscore = name.find('_'); name.find('!') != std::string_view::npos && underscore != std::string_view::npos)
        name = name.substr(0, underscore);
    if (name.size() > 4 && contains_folded(name.substr(name.size() - 4), ".exe")) name.remove_suffix(4);
    return std::string(name);
}

// The best-ranked session; among "other" apps, the system's current session, else the first.
inline std::size_t choose_session(const std::vector<std::string>& app_ids,
                                  std::optional<std::size_t> current) noexcept {
    std::size_t best = no_session;
    int best_rank = 3;
    for (std::size_t i = 0; i < app_ids.size(); ++i) {
        const int rank = session_rank(app_ids[i]);
        if (rank < best_rank || (rank == 2 && best_rank == 2 && current && *current == i)) {
            best = i;
            best_rank = rank;
        }
    }
    return best;
}
} // namespace dingosdk::your_music
