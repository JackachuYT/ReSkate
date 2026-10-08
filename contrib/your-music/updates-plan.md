# Your Music, Automatic Updates Plan

Goal (user's design, 2026-10-08): players install **once**, then everything stays up to date with no
prompts. Installing opts in to all updates.

## Pieces

| Piece | Where | What it does |
|---|---|---|
| Follow robot | `.github/workflows/follow-reskate.yml` | Every 3 h: if ReSkate published a release that `main` isn't built on, rebase our commits onto that tag, push `main` and the tag, tag `your-music-v<reskate>-1`, dispatch the build. A rebase conflict fails the run (GitHub emails the owner); players stay on the last release. |
| Build + release | `.github/workflows/your-music.yml` | Tags `your-music-v<x.y.z>-<n>` build `ReSkate.dll` with version `<x.y.z>-yourmusic.<n>` and publish a full (latest) release with `ReSkate-YourMusic.zip` and `your-music.json`. |
| Manifest | `your-music.json` release asset | `version`, `reskate` (base tag), `game_sha256` (Skate.exe that build supports), `zip` (name, sha256, size), `launcher` (official ReSkateLauncher.exe for the base tag: url, sha256, size). |
| Shared script | `package/your-music-common.ps1` | Paths, logging to `YourMusic\update.log`, launcher "updates" setting, building `Mods\YourMusic` with ReSkateMusicPacker. |
| Installer | `package/install-your-music.ps1` | One time: build the mod, turn the launcher's own updates off, register the hidden scheduled task, run the updater once. |
| Updater | `package/update-your-music.ps1` | No prompts. Skips while Skate or the launcher runs. Installs the official launcher matching our base, a newer Your Music zip (`ReSkate.dll` + `YourMusic\`), keeps launcher updates off, rebuilds the mod when the supported Skate.exe changes. Verifies every download's SHA-256. |
| Uninstaller | `package/uninstall-your-music.ps1` + `.bat` | Removes the task and `Mods\YourMusic`, turns launcher updates back on (the launcher then restores the official `ReSkate.dll`). |

## Scheduled task

Name `Your Music for ReSkate updater`, current user, limited rights, visible in Task Scheduler (no window when it runs), triggers hourly (and at
log on when Windows allows it without admin). Action: `conhost.exe --headless powershell.exe
-NoProfile -NonInteractive -ExecutionPolicy Bypass -File <kit>\update-your-music.ps1`, so no window
flashes. `-MultipleInstances IgnoreNew`, one-hour time limit.

## Constraints

- Scripts run on Windows PowerShell 5.1: `-UseBasicParsing`, TLS 1.2, no PowerShell 7 syntax.
- Only HTTPS downloads from github.com release assets; every file checked against the manifest's SHA-256
  before it replaces anything. Only files inside the skate. folder are touched.
- Version shown in game: `ReSkate <x.y.z>-yourmusic.<n> loaded`.

## Verification

- CI: build, tests, packaging, manifest generation.
- Local (Mac): PowerShell syntax can't be checked without `pwsh`; review by reading. Manifest logic is
  checked in CI by parsing the generated JSON.
- In game (user): install once, confirm the task exists (Task Scheduler), `YourMusic\update.log` shows
  "up to date", and a later release arrives without doing anything.
