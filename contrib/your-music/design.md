# ReSkate "Your Music" — Design

Date: 2026-10-08
Status: approved by user, pending spec review
Upstream: [Dingo-Shenanigans/ReSkate](https://github.com/Dingo-Shenanigans/ReSkate) at `d04920c` (game build `20260929`, Steam build `25414733`)

## Summary (plain language)

A ReSkate feature that replaces skate.'s soundtrack with your own Apple Music and Spotify playlists and
albums. Your playlists and albums appear as tiles, with their cover art, in the game's own music screen.
Picking one silences the game's soundtrack and plays your music; picking a game playlist brings the
soundtrack back. The game's skip button skips your songs, and a small card shows the current song.

The audio is played by a real music player on the PC (a minimized Microsoft Edge window for Apple Music,
the Spotify app for Spotify), not decoded by the game. Streaming services encrypt their audio and never
hand it to third-party programs, so this is the only legitimate way to do it.

## Goals

1. Show the player's music collections (playlists and albums) as tiles in the native Music Playlist
   Manager, with cover art.
2. Picking one of those tiles silences the game's music and starts that collection in the player's app.
3. Picking a game playlist pauses the player's app and the game's soundtrack resumes.
4. The in-game Next control skips to the next song in the player's app.
5. A small overlay card shows the current song (title, artist, cover) for a few seconds on each change.
6. Works with Apple Music (step 2) and Spotify (step 3), plus a generic "Your Music" tile that controls
   whatever app is playing (step 1).

## Non-goals

- Feeding streamed audio into the game's audio engine. It is DRM-protected; capturing it would break
  Apple's and Spotify's terms.
- Showing the individual songs of a collection inside the game's song list. Each tile holds one silent
  placeholder song (see below); song info appears on the overlay card instead.
- macOS support. ReSkate and skate. are Windows-only.
- Letting other players in multiplayer hear the music. Everything is local to one PC.
- The in-game Previous control. We will wire it up if step 1 finds a usable hook, but it is not required.

## Delivery steps

| Step | Delivers | Needs from the user |
|---|---|---|
| 1 | Game-side plumbing + generic "Your Music" tile controlling any app via Windows media controls | Download, install, play, report |
| 2 | Apple Music playlists and albums as tiles | MusicKit key (.p8), Key ID, Team ID; one-time Apple Music sign-in |
| 3 | Spotify playlists and albums as tiles | Spotify Premium; a Spotify developer app's Client ID; one-time sign-in |

Each step has its own implementation plan. Step 1 includes a short investigation (see Open questions).

**Step 1 keeps to the smallest version that proves the game side** (plan: `step1-plan.md`):

- The "Your Music" tile comes from the companion mod's own `reskate-music.json`, so step 1 needs no
  `collection_provider`.
- Step 1 has one source (the Windows media controls), so it uses `media_session` directly. The
  `MusicSource` interface arrives in step 2, when there is a second source.
- Song pop-ups use ReSkate's existing top-left corner notices (title, artist, app; text only). The
  cover-art card arrives in step 2, which downloads artwork anyway.
- Pausing the app when the game exits moves to step 2: ReSkate has no clean shutdown hook to use yet.

## Where the code lives

- A fork of ReSkate on the user's GitHub account (`JackachuYT/ReSkate`), branch `your-music`. The fork is
  public, as GPL-3.0 requires for a distributed modified ReSkate.
- New code goes in `Extension/YourMusic/`, following ReSkate's layout. Game addresses and fingerprints
  go in `Engine/Game/Build/20260929/your_music.h`, never in feature code (ReSkate rule).
- Local checkout: `/Users/jackachu/Documents/aura/reskate-your-music/` (this folder).
- The user has no Windows build tools. A GitHub Actions workflow on `windows-latest` builds Release,
  runs the unit tests and uploads a zip containing `ReSkate.dll`, `ReSkateLauncher.exe` and
  `Mods/YourMusic/`. Builds keep `DINGOSDK_LAUNCHER_AUTO_UPDATE=OFF` so the launcher never replaces our
  DLL with the official one.
- The user installs by extracting the zip beside `Skate.exe` (step 2 of ReSkate's own install guide).

## How it works

### The silent placeholder song

ReSkate only shows a mod playlist if at least one of its songs is a registered music asset, and the game
has no existing ReSkate hook for muting music. So a companion mod, `Mods/YourMusic/`, adds one silent
song (`Your Music - Playing from your app`) through the standard music-mod packaging that existing
Thunderstore music mods use. Every "Your Music" tile lists that one song.

Music mods are built by [ReSkateMusicPacker](https://github.com/DeckardDetribine/ReSkateMusicPacker)
(GPL-3.0), which reads the installed game's files, so it cannot run on our build server. The release zip
bundles the packer (v1.1.3, pinned by SHA-256), a tagged silent FLAC and a double-click installer that
builds `Mods\YourMusic` on the player's PC. Re-running it after a game or ReSkate update rebuilds the mod.

When the game's radio plays the placeholder, it is silent, so the player's app is the only music heard.
When it plays anything else, the app is paused. No volume hooking is needed.

The placeholder is 20 minutes long, so its natural end is rare and can be told apart from a Next press by
elapsed time. (The packer's codec header caps a song at about 23 minutes.)

### Components

```
                    ┌──────────────────────────── skate. process (ReSkate.dll) ──────────────────────────┐
                    │                                                                                      │
 Music screen ─────►│ collection_provider ──► ReSkate mod-playlist list (+ artwork server)                 │
 (tiles)            │        ▲                                                                             │
                    │        │ collections                                                                 │
                    │   MusicSource (interface)                                                            │
                    │   ├─ AnyAppSource      ── media_session (Windows media controls) ──► any player app  │
                    │   ├─ AppleMusicSource  ── player_bridge (127.0.0.1) ◄──► Edge app window (MusicKit)  │
                    │   └─ SpotifySource     ── Spotify Web API (HTTPS) ──► Spotify app on this PC          │
                    │        ▲                                                                             │
 Radio queue ──────►│ radio_hook ──► handoff_policy ──► commands (play collection / pause / next)          │
 (select-next hook) │                                                                                      │
                    │ now_playing_card (ImGui overlay) ◄── current track from the active source            │
                    │ settings panel (ReSkate menu → Your Music)                                           │
                    └──────────────────────────────────────────────────────────────────────────────────────┘
```

**`MusicSource`** (`music_source.h`): the one interface the rest of the feature talks to.

```cpp
struct Collection {
    std::string id;          // stable within the source, e.g. "apple:p.AbC123", "spotify:album:4aaw…"
    enum class Kind { playlist, album, any_app } kind;
    std::string name;
    std::filesystem::path artwork_png; // cached PNG, empty when none
};
struct NowPlaying { std::string title, artist, album; std::filesystem::path artwork_png; bool playing; };

class MusicSource {
public:
    virtual ~MusicSource() = default;
    virtual std::string_view name() const = 0;            // "Apple Music", "Spotify", "Your Music"
    virtual std::vector<Collection> collections() = 0;    // cached; never blocks on the network
    virtual void play(const std::string& collection_id) = 0;
    virtual void pause() = 0;
    virtual void next() = 0;
    virtual std::optional<NowPlaying> now_playing() = 0;
    virtual std::string status() const = 0;              // "Signed in", "Open Spotify to play", …
};
```

All methods are non-blocking from the game's point of view: network and Windows API work runs on a
source-owned worker thread, and methods read or enqueue against that thread.

**`media_session`** (step 1): wraps Windows System Media Transport Controls
(`GlobalSystemMediaTransportControlsSessionManager`, C++/WinRT from the Windows SDK, no new
dependencies). Reports title, artist, album, thumbnail and playback state, and sends play, pause, next
and previous. Session choice: Spotify if it has a session, else Apple Music, else the system's current
session. `AnyAppSource` is a thin wrapper exposing one collection, "Your Music".

**`collection_provider`**: adds the active sources' collections to the list `mod_music_playlists()`
returns (`Extension/Music/local_music_assets.cpp`), as playlists with id
`mod:YourMusic:<source>:<collection id>`, name = collection name, songs = [placeholder song id]. Cover
art is written as PNG to `%LOCALAPPDATA%\ReSkate\YourMusic\artwork\` and registered with the existing
`MusicArtworkServer` using that folder as the mod root, so the artwork server needs no changes. We keep
ReSkate's per-mod limit of 64 playlists: all playlists first, then albums by most recently added, up to
64 tiles in total. The game re-reads this list each time the music screen opens, so new collections appear on the
next visit.

**`radio_hook`**: reads the radio's current song and playlist from ReSkate's existing select-next hook
(`Extension/Music/local_music_playback.cpp`) and from the queue state it already resolves, and turns them
into events for the handoff policy: `entered(collection_id)`, `left`, `next_pressed`, `looped`. It also
reports `game_exiting` from ReSkate's shutdown path.

**`handoff_policy.h`**: pure logic, no Windows or game calls, unit-tested.

| Event | Command |
|---|---|
| Radio switches onto a Your Music tile | `play(collection)` |
| Radio switches from a Your Music tile to a game song | `pause()` |
| Select-next fires on the placeholder before its natural end (elapsed < length − 2 s) | `next()` |
| Placeholder reaches its natural end and loops | nothing |
| Game exits while a Your Music tile is active | `pause()` |
| Player paused their app manually | nothing; we never re-send play until the next tile switch |

The policy reacts only to transitions, never to steady state, so it never fights the player's own
controls.

**`now_playing_card`**: a Dear ImGui overlay card (ReSkate already renders ImGui overlays) in the top
right, showing cover art, title and artist for 5 seconds after each song change while a Your Music tile is
active. Setting: Pop up (default), Always, Off.

**Settings panel**: a "Your Music" section in the ReSkate menu (Insert). It holds the card setting, each
source's status line, and the sign-in controls for steps 2 and 3. Preferences are stored like ReSkate's
existing local profile preferences (e.g. `ReSkate.MusicShuffle`), under `ReSkate.YourMusic.*`.

### Step 2: Apple Music

The Apple Music app for Windows has no control API, so playback runs in Apple's web player library,
MusicKit JS v3, inside a Microsoft Edge app window that ReSkate launches.

- **Developer token.** The user downloads a MusicKit private key (`.p8`) from their Apple Developer
  account and puts it in `%LOCALAPPDATA%\ReSkate\YourMusic\apple\`, then enters its Key ID and their Team
  ID in the settings panel. ReSkate signs an ES256 JWT locally with Windows CNG (`BCrypt`), valid for 30
  days, re-signed automatically. The key never leaves the PC and is not in the repository.
- **Player bridge.** ReSkate serves `player.html` and a small JSON API on `http://127.0.0.1:47821/`
  (fixed port, so the browser origin and the saved Apple Music sign-in stay stable). It launches
  `msedge.exe --app=http://127.0.0.1:47821/ --user-data-dir=%LOCALAPPDATA%\ReSkate\YourMusic\edge`
  and minimizes the window after the first successful sign-in.
- **Page ↔ ReSkate.** The page polls `GET /command` every 250 ms and posts `POST /state` (now playing,
  playback state, errors) and `POST /library`. No WebSocket is needed.
- **Library.** The page reads `/v1/me/library/playlists` and `/v1/me/library/albums` through MusicKit
  (paginated) and posts them to ReSkate. ReSkate downloads cover art (WinHTTP), converts it to PNG (WIC)
  and caches the list as JSON so tiles appear even before Edge starts.
- **Playback.** `play` → `music.setQueue({playlist|album: id})` then `music.play()`. `next` →
  `music.skipToNextItem()`. `pause` → `music.pause()`.
- **First run.** The Edge window opens visibly with a "Sign in to Apple Music" button (MusicKit
  `authorize()`), then minimizes itself.

### Step 3: Spotify

- **Setup.** The user creates a Spotify developer app (Premium required by Spotify since 2026-02),
  adds redirect URI `http://127.0.0.1:47822/callback`, and pastes the Client ID into the settings panel.
  Step-by-step instructions ship with the release.
- **Sign-in.** OAuth Authorization Code with PKCE (no client secret) in the default browser; the loopback
  listener on port 47822 receives the code. The refresh token is encrypted with DPAPI
  (`CryptProtectData`) in `%LOCALAPPDATA%\ReSkate\YourMusic\spotify\`. Spotify ends refresh tokens six
  months after sign-in; the status line then asks the user to sign in again.
- **Library.** `GET /me/playlists` and `GET /me/albums` (both still available to Development Mode apps
  after the February 2026 changes), cached with artwork the same way as Apple Music.
- **Playback.** Find this PC's Spotify Connect device with `GET /me/player/devices` (launching Spotify
  with the `spotify:` URI if it is not running), then `PUT /me/player/play?device_id=…` with the
  collection's `context_uri`. Next and pause go through the Windows media controls on the Spotify app.

## Error handling

- **Wrong game or ReSkate build.** Every new hook checks its fingerprint before installing, like
  ReSkate's existing hooks. On a mismatch the feature turns itself off, logs why, and the game's own music
  works normally.
- **Placeholder mod missing.** No Your Music tiles are shown; the settings panel says the companion mod
  is missing.
- **Source not ready** (not signed in, app closed, offline, token expired). Tiles still show from the
  cache. Picking one shows the card with a short fix, e.g. "Apple Music: sign in from the ReSkate menu
  (Insert)". The radio stays on the silent placeholder until the player picks something else.
- **Network.** Library refresh and art downloads retry with backoff on the worker thread; the game thread
  never waits on the network.
- **Secrets.** Tokens are encrypted with DPAPI; the `.p8` stays where the user put it. Logs never
  contain tokens, keys or auth codes.

## Testing

- **Unit tests** in `Extension/YourMusic/Test/`, registered with CTest the way ReSkate's music tests are:
  handoff policy (every row of the table above), collection-to-playlist mapping and the 64 cap, JWT
  header and claims, PKCE verifier and challenge, Apple and Spotify response parsing, and the bridge's
  command and state JSON.
- **CI**: GitHub Actions on `windows-latest` builds with ReSkate's `/W4 /WX`, runs the unit tests and
  publishes the zip.
- **In-game acceptance** (done by the user on their PC, from a checklist shipped with each build):
  tiles appear with art; picking one silences the game and starts the music; Next skips; switching to a
  game playlist pauses the music and the soundtrack returns; manual pause isn't overridden; the card
  shows on song change; changing maps and reopening the music screen still work; quitting the game
  pauses the music.

## Open questions (resolved in step 1's investigation)

1. ~~**How music mods package songs.**~~ Resolved: ReSkateMusicPacker (see "The silent placeholder
   song").
2. **Reading the current song and playlist.** Confirm the radio queue exposes the playing song's GUID
   and the mod playlist id (`mod:` prefix) at the select-next hook. ReSkate already resolves the queue's
   channel and playlist binding there.
3. **Next vs. natural end.** Confirm the elapsed-time rule works, or find a separate UI-Next path.
4. **Previous.** Find whether the Previous control has a hookable path (optional feature).
5. **Shutdown.** Find ReSkate's shutdown path for the `game_exiting` event.
6. **Step 2 risk.** Confirm MusicKit JS authorization and DRM playback work in an Edge app window on
   `http://127.0.0.1` (browsers treat loopback as a secure context, so DRM should be available). If
   Apple's sign-in rejects that origin, host `player.html` on the user's GitHub Pages over HTTPS and keep
   only the JSON bridge on loopback. Never install certificates on the user's PC.
