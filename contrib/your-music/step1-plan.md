# Your Music, Step 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A "Your Music" tile in skate.'s music screen. Picking it silences the game and plays whatever music app is open (Spotify, Apple Music, anything with Windows media controls). The game's Next skips the app's song, and a corner pop-up shows the song name.

**Architecture:** A companion music mod adds a 20-minute silent song and a "Your Music" playlist; the user's PC builds it with ReSkateMusicPacker (it needs the game's files). ReSkate's existing select-next hook tells a new `your_music` module which song the radio picked. A pure policy turns that into play/pause/next. A worker thread sends those to the music app through Windows media controls (System Media Transport Controls, C++/WinRT) and posts song pop-ups through ReSkate's existing corner notices. GitHub Actions builds everything, because the user has no Windows build tools.

**Tech Stack:** C++20, MSVC v143 (`/W4 /WX /permissive- /EHsc`), CMake presets, C++/WinRT (`Windows.Media.Control`, from the Windows SDK), Dear ImGui (existing ReSkate menu helpers), PowerShell, GitHub Actions `windows-2022`.

## Global Constraints

- Spec: `contrib/your-music/design.md`. Branch: `main` on `JackachuYT/ReSkate` (originally `your-music`).
- Supported game build only: `Engine/Game/Build/20260929` (Steam build `25414733`). No new game addresses are needed in step 1.
- Builds must keep `DINGOSDK_LAUNCHER_AUTO_UPDATE=OFF` and set `DINGOSDK_BACKTRACE_URL` empty (no crash uploads to the ReSkate project's account from our modified build).
- Warnings are errors (`/W4 /WX`). New code compiles warning-free under MSVC; pure headers also compile with `clang++ -std=c++20 -Wall -Wextra -Werror` on the Mac for fast test runs.
- Never block a game thread: WinRT calls happen only on the media worker thread.
- Placeholder song id: exactly `Your Music - Playing from your app`. Length 1200 s (the packer's codec header limit is about 23 minutes).
- Mod folder name `YourMusic`, playlist name `Your Music`.
- Source text stays ASCII (no `/utf-8` flag in this project).
- Pinned tool: ReSkateMusicPacker v1.1.3, `ReSkateMusicPacker-v1.1.3-win64.zip`, sha256 `4800a3b73d3072488ec1ab6b938eff7df3f2cc46e7ed25d04e27677639ab61f7`.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## File map

| File | Status | Responsibility |
|---|---|---|
| `.github/workflows/your-music.yml` | new | Windows build, tests, packaging, prerelease on `your-music-v*` tags |
| `contrib/your-music/package.ps1` | new | Stages the release zip |
| `contrib/your-music/package/HOW TO INSTALL.txt` | new | Plain-language install steps |
| `contrib/your-music/package/TEST CHECKLIST.txt` | new | What the user checks in game |
| `contrib/your-music/package/Install Your Music.bat` | new | Double-click entry point |
| `contrib/your-music/package/install-your-music.ps1` | new | Gets ffmpeg, builds `Mods\YourMusic` with the packer |
| `contrib/your-music/package/song/Your Music - Playing from your app.flac` | new | 20 min of tagged digital silence |
| `Extension/YourMusic/handoff_policy.h` | new | Pure: radio select -> play/pause/next |
| `Extension/YourMusic/media_session_choice.h` | new | Pure: which app session to control, its display name |
| `Extension/YourMusic/media_session.h/.cpp` | new | WinRT worker: commands, now playing, pop-ups |
| `Extension/YourMusic/radio_hook.h/.cpp` | new | Reads the picked song from the radio queue, runs the policy |
| `Extension/YourMusic/Test/handoff_policy_tests.cpp` | new | Policy tests |
| `Extension/YourMusic/Test/media_session_choice_tests.cpp` | new | Session choice tests |
| `Extension/Music/local_music_playback.cpp` | modify | Call the radio hook after the native select-next |
| `Extension/Profile/local_profile_runtime.cpp` | modify | Start the worker, load the preference, reset on level change |
| `Extension/UI/Overlay/skate_menu_settings.cpp` | modify | "YOUR MUSIC" settings card |
| `cmake/Runtime.cmake`, `cmake/Apps.cmake` | modify | Sources, `windowsapp` link, tests |

---

### Task 1: Windows build and release pipeline

Delivers a downloadable zip of an unmodified-behaviour ReSkate built by our CI, so the user can check our build runs on their PC before any feature code exists.

**Files:**
- Create: `.github/workflows/your-music.yml`
- Create: `contrib/your-music/package.ps1`
- Create: `contrib/your-music/package/HOW TO INSTALL.txt`

**Interfaces:**
- Produces: release asset `ReSkate-YourMusic.zip` with `ReSkate.dll`, `ReSkateLauncher.exe`, `HOW TO INSTALL.txt`, `licenses/` at its root. Later tasks add files to `contrib/your-music/package/` and `package.ps1` copies them.

- [ ] **Step 1: Write the workflow**

`.github/workflows/your-music.yml`:

```yaml
name: your-music

on:
  push:
    branches: [your-music]
    tags: ["your-music-v*"]
  workflow_dispatch:

permissions:
  contents: write

jobs:
  build:
    runs-on: windows-2022
    steps:
      - uses: actions/checkout@v4

      - name: Configure
        run: cmake --preset vs2022-x64 -DDINGOSDK_BUILD_LAUNCHER_TESTS=ON -DDINGOSDK_LAUNCHER_AUTO_UPDATE=OFF "-DDINGOSDK_BACKTRACE_URL="

      - name: Build
        run: cmake --build --preset release --parallel 4 --target dingosdk_runtime dingosdk_launcher dingosdk_music_playback_policy_tests

      - name: Test
        run: ctest --test-dir build/vs2022-x64 -C Release -R "^music_playback_policy$" --output-on-failure --no-tests=error

      - name: Get ReSkate Music Packer
        shell: pwsh
        run: |
          $url = "https://github.com/DeckardDetribine/ReSkateMusicPacker/releases/download/v1.1.3/ReSkateMusicPacker-v1.1.3-win64.zip"
          Invoke-WebRequest $url -OutFile packer.zip
          $hash = (Get-FileHash packer.zip -Algorithm SHA256).Hash.ToLowerInvariant()
          if ($hash -ne "4800a3b73d3072488ec1ab6b938eff7df3f2cc46e7ed25d04e27677639ab61f7") { throw "ReSkate Music Packer zip changed: $hash" }
          Expand-Archive packer.zip -DestinationPath packer

      - name: Package
        shell: pwsh
        run: ./contrib/your-music/package.ps1 -Build build/vs2022-x64/Release -Packer packer -Out ReSkate-YourMusic.zip

      - uses: actions/upload-artifact@v4
        with:
          name: ReSkate-YourMusic
          path: ReSkate-YourMusic.zip

      - name: Publish prerelease
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v2
        with:
          files: ReSkate-YourMusic.zip
          prerelease: true
```

- [ ] **Step 2: Write the packaging script**

`contrib/your-music/package.ps1` (copies whatever exists in `package/`, so later tasks only add files):

```powershell
param(
    [Parameter(Mandatory)] [string] $Build,
    [Parameter(Mandatory)] [string] $Packer,
    [Parameter(Mandatory)] [string] $Out
)
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$kit = Join-Path $PSScriptRoot 'package'
$stage = Join-Path ([System.IO.Path]::GetTempPath()) 'your-music-package'
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stage, (Join-Path $stage 'licenses') | Out-Null

Copy-Item (Join-Path $Build 'ReSkate.dll'), (Join-Path $Build 'ReSkateLauncher.exe') $stage
Get-ChildItem $kit -File | Copy-Item -Destination $stage

$modKit = Join-Path $stage 'YourMusic'
if (Test-Path (Join-Path $kit 'song')) {
    New-Item -ItemType Directory -Path $modKit | Out-Null
    Get-ChildItem $kit -Directory | Copy-Item -Destination $modKit -Recurse
    Copy-Item $Packer (Join-Path $modKit 'packer') -Recurse
}

Copy-Item (Join-Path $root 'LICENSE') (Join-Path $stage 'licenses\ReSkate-LICENSE.txt')
Get-ChildItem (Join-Path $root 'External') -Recurse -File -Include 'LICENSE*', 'COPYING*' | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $stage ('licenses\' + $_.Directory.Name + '-' + $_.Name))
}
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $Out -Force
Write-Host "Packaged $Out"
```

Files directly in `package/` go to the zip root; once Task 2 adds `package/song/`, every subfolder of `package/` plus the packer goes into `YourMusic/`.

- [ ] **Step 3: Write the install guide (step 1 version)**

`contrib/your-music/package/HOW TO INSTALL.txt`:

```text
YOUR MUSIC FOR RESKATE - HOW TO INSTALL
=======================================

You need: skate. on Steam, already working with ReSkate on this PC.

1. Close skate. and the ReSkate launcher.

2. Open your skate. folder:
   Steam -> right-click skate. -> Manage -> Browse local files.
   (It's the folder with Skate.exe in it.)

3. Copy EVERYTHING from this zip into that folder.
   If Windows asks, choose "Replace the files in the destination".

4. Start ReSkateLauncher.exe from that folder.
   If Windows says "Windows protected your PC", click "More info", then "Run anyway".

5. Press PLAY. A note in the top-left corner should say
   "ReSkate loaded (development build)". That means it's our version.

To go back to normal ReSkate: download it again from
https://github.com/Dingo-Shenanigans/ReSkate/releases and copy it over these files.
```

- [ ] **Step 4: Validate the YAML and script locally**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/your-music.yml')); print('ok')"`
Expected: `ok`

Run: `pwsh -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('contrib/your-music/package.ps1',[ref]\$null,[ref]\$e) | Out-Null; \$e.Count"` (skip if `pwsh` is not installed)
Expected: `0`

- [ ] **Step 5: Commit, push, and watch CI**

```bash
git add .github/workflows/your-music.yml contrib/your-music/package.ps1 "contrib/your-music/package/HOW TO INSTALL.txt"
git commit -m "Your Music: Windows build and release pipeline"
git push -u origin your-music
gh run watch --exit-status $(gh run list --branch your-music --limit 1 --json databaseId --jq '.[0].databaseId')
```

Expected: the run succeeds and has a `ReSkate-YourMusic` artifact. If configure fails because the preset's generator is missing, read the log and fix the runner image or generator before continuing.

- [ ] **Step 6: Tag the first prerelease**

```bash
git tag your-music-v0.1.0 && git push origin your-music-v0.1.0
```

Expected: a prerelease at `https://github.com/JackachuYT/ReSkate/releases/tag/your-music-v0.1.0` with `ReSkate-YourMusic.zip`. **User checkpoint:** the user installs it and confirms the "development build" notice appears and the game plays normally.

---

### Task 2: The Your Music placeholder mod kit

Delivers the silent song and a double-click installer that builds `Mods\YourMusic` on the user's PC.

**Files:**
- Create: `contrib/your-music/package/song/Your Music - Playing from your app.flac`
- Create: `contrib/your-music/package/Install Your Music.bat`
- Create: `contrib/your-music/package/install-your-music.ps1`
- Modify: `contrib/your-music/package/HOW TO INSTALL.txt`
- Modify: `contrib/your-music/package.ps1` (move the scripts into `YourMusic/`)

**Interfaces:**
- Produces: in game, mod playlist `mod:YourMusic:Your Music` containing one song with id `Your Music - Playing from your app`. Tasks 4-5 rely on that id.

- [ ] **Step 1: Make the silent song**

```bash
mkdir -p "contrib/your-music/package/song"
ffmpeg -v error -y -f lavfi -i anullsrc=r=48000:cl=stereo -t 1200 -c:a flac -sample_fmt s16 \
  -metadata artist="Your Music" -metadata title="Playing from your app" \
  "contrib/your-music/package/song/Your Music - Playing from your app.flac"
ffprobe -v error -show_entries format=duration:format_tags=artist,title -of json \
  "contrib/your-music/package/song/Your Music - Playing from your app.flac"
```

Expected: `"duration": "1200.000000"`, `"artist": "Your Music"`, `"title": "Playing from your app"`. File about 200 KB.

- [ ] **Step 2: Write the installer script**

`contrib/your-music/package/install-your-music.ps1` (it ends up in `<skate folder>\YourMusic\`):

```powershell
# Builds the Your Music companion mod (one silent song and the "Your Music" playlist) into
# Mods\YourMusic beside Skate.exe. ReSkateMusicPacker needs this PC's game files, so this
# runs here rather than on our build server.
$ErrorActionPreference = 'Stop'
$kit = $PSScriptRoot
$game = Split-Path $kit -Parent
$packer = Join-Path $kit 'packer\ReSkateMusicPacker.exe'
$ffmpeg = Join-Path $kit 'ffmpeg'

function Invoke-Packer([string[]] $Arguments) {
    # The packer is a windowed app; Start-Process -Wait keeps its console output here and waits for it.
    $quoted = $Arguments | ForEach-Object { '"' + $_ + '"' }
    $process = Start-Process -FilePath $packer -ArgumentList ($quoted -join ' ') -Wait -NoNewWindow -PassThru
    return $process.ExitCode
}

try {
    if (-not (Test-Path (Join-Path $game 'Skate.exe'))) {
        throw "Put the YourMusic folder inside your skate. folder (the one with Skate.exe), then run this again."
    }
    if (Get-Process -Name 'Skate' -ErrorAction SilentlyContinue) {
        throw "Close skate. first, then run this again."
    }
    Write-Host 'Step 1 of 2: getting ffmpeg (only needed the first time, about 100 MB)...'
    if (-not (Test-Path (Join-Path $ffmpeg 'ffmpeg.exe'))) {
        if ((Invoke-Packer @('--get-ffmpeg', $ffmpeg)) -ne 0) { throw 'Could not download ffmpeg.' }
    }
    $env:PATH = $ffmpeg + ';' + $env:PATH

    Write-Host 'Step 2 of 2: building the Your Music mod...'
    $out = Join-Path $game 'Mods\YourMusic'
    $arguments = @($game, (Join-Path $kit 'song'), $out, '--name', 'YourMusic', '--playlist', 'Your Music',
                   '--no-normalize', '--bitrate', '64', '--generate-playlist-artwork', 'Your Music')
    if ((Invoke-Packer $arguments) -ne 0) { throw 'The music packer failed. The messages above say why.' }

    Write-Host ''
    Write-Host 'Done! Now open ReSkateLauncher, go to MODS, and make sure YourMusic is turned on.' -ForegroundColor Green
} catch {
    Write-Host ''
    Write-Host $_.Exception.Message -ForegroundColor Red
}
Read-Host 'Press Enter to close'
```

- [ ] **Step 3: Write the double-click entry point**

`contrib/your-music/package/Install Your Music.bat`:

```bat
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-your-music.ps1"
```

- [ ] **Step 4: Put the scripts inside `YourMusic/` in the zip**

The scripts must sit in `YourMusic\` so `$PSScriptRoot`'s parent is the skate. folder. In `contrib/your-music/package.ps1`, replace

```powershell
Get-ChildItem $kit -File | Copy-Item -Destination $stage
```

with

```powershell
$scripts = 'Install Your Music.bat', 'install-your-music.ps1'
Get-ChildItem $kit -File | Where-Object { $scripts -notcontains $_.Name } | Copy-Item -Destination $stage
```

and after the line `Copy-Item $Packer (Join-Path $modKit 'packer') -Recurse` add

```powershell
    $scripts | ForEach-Object { Copy-Item (Join-Path $kit $_) $modKit }
```

- [ ] **Step 5: Update the install guide**

In `HOW TO INSTALL.txt`, replace step 5 with:

```text
5. Open the YourMusic folder (it's now inside your skate. folder) and double-click
   "Install Your Music.bat". Wait until it says Done. The first time it downloads
   ffmpeg (about 100 MB), which it needs to build the mod.

6. In the ReSkate launcher, open MODS and make sure YourMusic is turned on.

7. Press PLAY. A note in the top-left corner should say
   "ReSkate loaded (development build)". That means it's our version.

8. In the game, open the music screen. You should see a "Your Music" playlist.
   Picking it makes the game go quiet. (Step 1 of the mod stops here for now.)

Run "Install Your Music.bat" again whenever skate. or ReSkate updates.
```

- [ ] **Step 6: Commit, push, watch CI, and list the zip**

```bash
git add contrib/your-music/package contrib/your-music/package.ps1
git commit -m "Your Music: silent placeholder song and installer"
git push
gh run watch --exit-status $(gh run list --branch your-music --limit 1 --json databaseId --jq '.[0].databaseId')
gh run download $(gh run list --branch your-music --limit 1 --json databaseId --jq '.[0].databaseId') -n ReSkate-YourMusic -D "$TMPDIR/ym" && unzip -l "$TMPDIR/ym/ReSkate-YourMusic.zip"
```

Expected listing includes `ReSkate.dll`, `ReSkateLauncher.exe`, `HOW TO INSTALL.txt`, `YourMusic/Install Your Music.bat`, `YourMusic/install-your-music.ps1`, `YourMusic/song/Your Music - Playing from your app.flac`, `YourMusic/packer/ReSkateMusicPacker.exe`.

- [ ] **Step 7: Tag `your-music-v0.2.0`**

```bash
git tag your-music-v0.2.0 && git push origin your-music-v0.2.0
```

**User checkpoint:** the installer finishes, the "Your Music" tile shows, and picking it is silent. Ask the user for `logs\ReSkate.log` if not.

---

### Task 3: Handoff policy

**Files:**
- Create: `Extension/YourMusic/handoff_policy.h`
- Test: `Extension/YourMusic/Test/handoff_policy_tests.cpp`
- Modify: `cmake/Apps.cmake` (inside the `if(DINGOSDK_BUILD_LAUNCHER_TESTS AND WIN32)` block, after the `music_artwork` test)

**Interfaces:**
- Produces (namespace `dingosdk::your_music`):
  - `inline constexpr std::uint64_t placeholder_length_ms = 1'200'000;`
  - `inline constexpr std::uint64_t natural_end_margin_ms = 2'000;`
  - `enum class Command { none, play, pause, next };`
  - `struct RadioState { bool active{}; std::uint64_t started_ms{}; };`
  - `struct Decision { Command command{}; RadioState state{}; };`
  - `constexpr Decision on_select(RadioState state, bool placeholder_picked, std::uint64_t now_ms) noexcept;`

- [ ] **Step 1: Write the failing test**

`Extension/YourMusic/Test/handoff_policy_tests.cpp`:

```cpp
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `clang++ -std=c++20 -Wall -Wextra -Werror -I. Extension/YourMusic/Test/handoff_policy_tests.cpp -o "$TMPDIR/ym_policy" && "$TMPDIR/ym_policy"`
Expected: compile error, `'Extension/YourMusic/handoff_policy.h' file not found`.

- [ ] **Step 3: Write the policy**

`Extension/YourMusic/handoff_policy.h`:

```cpp
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `clang++ -std=c++20 -Wall -Wextra -Werror -I. Extension/YourMusic/Test/handoff_policy_tests.cpp -o "$TMPDIR/ym_policy" && "$TMPDIR/ym_policy"`
Expected: `all passed`

- [ ] **Step 5: Register the test with CTest**

In `cmake/Apps.cmake`, after `add_test(NAME music_artwork COMMAND dingosdk_music_artwork_tests)`:

```cmake
    add_executable(dingosdk_your_music_policy_tests Extension/YourMusic/Test/handoff_policy_tests.cpp)
    dingosdk_configure_target(dingosdk_your_music_policy_tests)
    add_test(NAME your_music_policy COMMAND dingosdk_your_music_policy_tests)
```

In `.github/workflows/your-music.yml`, add `dingosdk_your_music_policy_tests` to the build `--target` list and change the test regex to `"^(music_playback_policy|your_music_.*)$"`.

- [ ] **Step 6: Commit**

```bash
git add Extension/YourMusic/handoff_policy.h Extension/YourMusic/Test/handoff_policy_tests.cpp cmake/Apps.cmake .github/workflows/your-music.yml
git commit -m "Your Music: radio handoff policy"
```

---

### Task 4: Media session (Windows media controls)

**Files:**
- Create: `Extension/YourMusic/media_session_choice.h`
- Test: `Extension/YourMusic/Test/media_session_choice_tests.cpp`
- Create: `Extension/YourMusic/media_session.h`
- Create: `Extension/YourMusic/media_session.cpp`
- Modify: `cmake/Runtime.cmake` (sources and `windowsapp`), `cmake/Apps.cmake` (test), `.github/workflows/your-music.yml` (target)

**Interfaces:**
- Produces (namespace `dingosdk::your_music`):
  - `inline constexpr std::size_t no_session = static_cast<std::size_t>(-1);`
  - `int session_rank(std::string_view app_id) noexcept;` (0 Spotify, 1 Apple Music, 2 other)
  - `std::string app_display_name(std::string_view app_id);`
  - `std::size_t choose_session(const std::vector<std::string>& app_ids, std::optional<std::size_t> current) noexcept;`
  - `enum class MediaCommand { play, pause, next };`
  - `struct NowPlaying { std::string app, title, artist; bool playing{}; };`
  - `void start_media_session() noexcept;`
  - `void send_media_command(MediaCommand command) noexcept;`
  - `void set_media_active(bool active) noexcept;`
  - `NowPlaying media_now_playing();`
  - `void set_media_popups(bool enabled) noexcept;`
  - `bool media_popups() noexcept;`

- [ ] **Step 1: Write the failing choice test**

`Extension/YourMusic/Test/media_session_choice_tests.cpp`:

```cpp
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
```

- [ ] **Step 2: Run it to verify it fails**

Run: `clang++ -std=c++20 -Wall -Wextra -Werror -I. Extension/YourMusic/Test/media_session_choice_tests.cpp -o "$TMPDIR/ym_choice" && "$TMPDIR/ym_choice"`
Expected: compile error, `'Extension/YourMusic/media_session_choice.h' file not found`.

- [ ] **Step 3: Write the choice header**

`Extension/YourMusic/media_session_choice.h`:

```cpp
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `clang++ -std=c++20 -Wall -Wextra -Werror -I. Extension/YourMusic/Test/media_session_choice_tests.cpp -o "$TMPDIR/ym_choice" && "$TMPDIR/ym_choice"`
Expected: `all passed`

- [ ] **Step 5: Write the media session interface**

`Extension/YourMusic/media_session.h`:

```cpp
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
```

- [ ] **Step 6: Write the worker**

`Extension/YourMusic/media_session.cpp`:

```cpp
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
```

`Json` is `dingosdk::Json` (`Engine/Core/Json/json.h`): `{{"key", value}, ...}` builds an object from strings, bools and integers.

- [ ] **Step 7: Build wiring**

In `cmake/Runtime.cmake`, after `Extension/Music/local_music_shelf.cpp`, add:

```cmake
    Extension/YourMusic/media_session.cpp
```

and append `windowsapp` to the `target_link_libraries(dingosdk_runtime PRIVATE ... ws2_32 xaudio2 ole32 ...)` list, after `ole32`.

In `cmake/Apps.cmake`, after the `your_music_policy` test:

```cmake
    add_executable(dingosdk_your_music_choice_tests Extension/YourMusic/Test/media_session_choice_tests.cpp)
    dingosdk_configure_target(dingosdk_your_music_choice_tests)
    add_test(NAME your_music_choice COMMAND dingosdk_your_music_choice_tests)
```

In `.github/workflows/your-music.yml`, add `dingosdk_your_music_choice_tests` to the build `--target` list.

- [ ] **Step 8: Commit, push, watch CI**

```bash
git add Extension/YourMusic cmake/Runtime.cmake cmake/Apps.cmake .github/workflows/your-music.yml
git commit -m "Your Music: Windows media controls worker"
git push
gh run watch --exit-status $(gh run list --branch your-music --limit 1 --json databaseId --jq '.[0].databaseId')
```

Expected: build and both `your_music_*` tests pass. If MSVC reports warnings from WinRT headers despite `push, 3`, add the reported warning numbers to a `#pragma warning(disable: ...)` inside the push block, and nowhere else.

---

### Task 5: Radio hook

**Files:**
- Create: `Extension/YourMusic/radio_hook.h`
- Create: `Extension/YourMusic/radio_hook.cpp`
- Modify: `Extension/Music/local_music_playback.cpp` (`music_select_next_hook`)
- Modify: `Extension/Profile/local_profile_runtime.cpp` (start, preference, level transition)
- Modify: `cmake/Runtime.cmake`

**Interfaces:**
- Consumes: `on_select`, `RadioState`, `Command` (Task 3); `send_media_command`, `set_media_active`, `start_media_session`, `set_media_popups` (Task 4); `profile_runtime::music_asset_type` (`Extension/Music/local_music_assets.h`); `profile_runtime::cosmetic_text` (`Extension/Customization/local_customization_runtime.h`); `addr::local_music::graph_asset_vtable`, `metadata_vtable`.
- Produces (namespace `dingosdk::your_music`):
  - `inline constexpr std::string_view placeholder_song_id = "Your Music - Playing from your app";`
  - `void on_radio_select(std::uintptr_t queue, std::uintptr_t playlist_asset, std::int32_t selected) noexcept;`
  - `void radio_before_level_transition() noexcept;`

- [ ] **Step 1: Write the header**

`Extension/YourMusic/radio_hook.h`:

```cpp
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
```

- [ ] **Step 2: Write the hook**

`Extension/YourMusic/radio_hook.cpp`. The queue and playlist layouts are the ones `Extension/Music/local_music_playback.cpp` already reads (`current_guid`): candidates at queue `+0x78/+0x80` (u32 asset indices), song entries at playlist `+0x60` with the count in the u32 before them, the queue lock at queue `+0x150`; artist and title from the graph's metadata as in `read_music_catalog`.

```cpp
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

// "artist - title" of the song at candidate `index`, as the game registers it.
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
```

- [ ] **Step 3: Call it from the select-next hook**

In `Extension/Music/local_music_playback.cpp`, add `#include "Extension/YourMusic/radio_hook.h"` after `#include "local_music_playback_policy.h"`, and replace

```cpp
std::int32_t __fastcall music_select_next_hook(std::uintptr_t queue, std::uintptr_t playlist_asset) {
    if (select_next) {
        apply_policy(queue, playlist_asset);
        return select_next(queue, playlist_asset);
    }
    return -1;
}
```

with

```cpp
std::int32_t __fastcall music_select_next_hook(std::uintptr_t queue, std::uintptr_t playlist_asset) {
    if (select_next) {
        apply_policy(queue, playlist_asset);
        const auto selected = select_next(queue, playlist_asset);
        dingosdk::your_music::on_radio_select(queue, playlist_asset, selected);
        return selected;
    }
    return -1;
}
```

- [ ] **Step 4: Start the worker and reset on map changes**

In `Extension/Profile/local_profile_runtime.cpp`, add includes after `#include "Extension/Music/local_music_playback.h"`:

```cpp
#include "Extension/YourMusic/media_session.h"
#include "Extension/YourMusic/radio_hook.h"
```

After `if (playback_ready) activate_music_playback();` add:

```cpp
        if (playback_ready) {
            dingosdk::your_music::set_media_popups(local_preference("YourMusicPopups").value_or(true));
            dingosdk::your_music::start_media_session();
        }
```

In `local_profile_before_level_transition`, after `music_shelf_before_level_transition(next);` add:

```cpp
    dingosdk::your_music::radio_before_level_transition();
```

- [ ] **Step 5: Build wiring**

In `cmake/Runtime.cmake`, after `Extension/YourMusic/media_session.cpp` add:

```cmake
    Extension/YourMusic/radio_hook.cpp
```

- [ ] **Step 6: Commit, push, watch CI**

```bash
git add Extension/YourMusic/radio_hook.h Extension/YourMusic/radio_hook.cpp Extension/Music/local_music_playback.cpp Extension/Profile/local_profile_runtime.cpp cmake/Runtime.cmake
git commit -m "Your Music: hand the radio off to the music app"
git push
gh run watch --exit-status $(gh run list --branch your-music --limit 1 --json databaseId --jq '.[0].databaseId')
```

Expected: green build.

---

### Task 6: Settings card, checklist, release

**Files:**
- Modify: `Extension/UI/Overlay/skate_menu_settings.cpp`
- Create: `contrib/your-music/package/TEST CHECKLIST.txt`
- Modify: `contrib/your-music/package/HOW TO INSTALL.txt`

**Interfaces:**
- Consumes: `media_popups`, `set_media_popups`, `media_now_playing` (Task 4); `profile_runtime::set_local_preference` (existing).

- [ ] **Step 1: Add the card**

In `Extension/UI/Overlay/skate_menu_settings.cpp`, add `#include "Extension/YourMusic/media_session.h"` after `#include "Extension/Music/local_music_playback.h"`, and right after the MUSIC PLAYBACK card's `end_card();` add:

```cpp
    begin_card(menu, "your-music", "YOUR MUSIC");
    bool popups = dingosdk::your_music::media_popups();
    if (toggle_row(menu, "Song pop-ups", "Show the song name when it changes while Your Music plays.", popups)) {
        dingosdk::your_music::set_media_popups(popups);
        dingosdk::profile_runtime::set_local_preference("YourMusicPopups", popups);
    }
    {
        const auto now = dingosdk::your_music::media_now_playing();
        const auto status = now.app.empty()
            ? std::string("No music app found. Open Spotify or Apple Music.")
            : "Controlling " + now.app + (now.title.empty() ? std::string() : ": " + now.title +
                (now.artist.empty() ? std::string() : " - " + now.artist));
        note(status.c_str());
    }
    note("Pick the Your Music playlist in the game's music screen to play it.");
    end_card();
```

- [ ] **Step 2: Write the test checklist**

`contrib/your-music/package/TEST CHECKLIST.txt`:

```text
YOUR MUSIC - THINGS TO TRY (tell Claude what happened for each)
===============================================================

Before you start: open Spotify or Apple Music and play any song, then pause it.

1. Start skate. with ReSkateLauncher. Press Insert -> SETTINGS.
   Does the YOUR MUSIC card say "Controlling Spotify" (or Apple Music)?

2. Open the game's music screen and pick the "Your Music" playlist.
   Does the game go quiet and your song start playing?
   Does a note with the song name pop up in the top-left corner?

3. Press the game's skip / next song button.
   Does your app skip to the next song?

4. Pick one of the game's own playlists.
   Does your app pause and the game's music come back?

5. Pick "Your Music" again, then pause your app yourself.
   Does it stay paused (the game shouldn't restart it)?

6. Fast travel or change map while Your Music is playing.
   Does your music keep going (or come back) after loading?

7. Turn "Song pop-ups" off in Insert -> SETTINGS -> YOUR MUSIC.
   Do the song-name notes stop?

If anything goes wrong, send Claude the file logs\ReSkate.log from your skate. folder.
```

- [ ] **Step 3: Update the install guide's last step**

In `HOW TO INSTALL.txt`, replace step 8 with:

```text
8. Open Spotify or Apple Music and play a song. Then, in the game, open the music
   screen and pick the "Your Music" playlist. The game goes quiet and your music plays.
   Then go through TEST CHECKLIST.txt.
```

- [ ] **Step 4: Commit, push, watch CI, tag**

```bash
git add Extension/UI/Overlay/skate_menu_settings.cpp "contrib/your-music/package/TEST CHECKLIST.txt" "contrib/your-music/package/HOW TO INSTALL.txt"
git commit -m "Your Music: settings card and test checklist"
git push
gh run watch --exit-status $(gh run list --branch your-music --limit 1 --json databaseId --jq '.[0].databaseId')
git tag your-music-v0.3.0 && git push origin your-music-v0.3.0
```

Expected: prerelease `your-music-v0.3.0` with the zip. **User checkpoint:** the user runs `TEST CHECKLIST.txt` and reports results plus `logs\ReSkate.log`. The `your_music_select` events in that log answer the spec's open questions 2 and 3 (what the radio picks on playlist switch, Next and map change); fix anything they show before planning step 2.
