# Your Music for skate.

Play your own Spotify or Apple Music in **skate.** instead of the game's soundtrack.

Pick the **Your Music** playlist in the game's music screen and the game goes quiet while your music
app plays. The game's skip button skips your songs, and the song name pops up in the corner. Pick any of
the game's own playlists and your music pauses while the soundtrack comes back.

> **Early test version.** It works with whatever music app is open on your PC (Spotify, Apple Music,
> and most others). Your own Apple Music and Spotify playlists and albums showing up as their own tiles
> in the game is coming next.

Your Music is a fan project. It is not affiliated with or endorsed by Electronic Arts, Full Circle or
the ReSkate team.

## What you need

- A Windows PC with **skate.** on Steam.
- **[ReSkate](https://github.com/Dingo-Shenanigans/ReSkate)** already working on it.
- **Spotify** or **Apple Music** (the Windows app), or any other music app.

## How to install

You only do this **once**. After that, Your Music keeps itself **and ReSkate** up to date automatically,
in the background, with no pop-ups.

1. Download `ReSkate-YourMusic.zip` from the **[latest release](https://github.com/JackachuYT/ReSkate/releases/latest)**.
2. Close skate. and the ReSkate launcher.
3. Open your skate. folder: in Steam, right-click **skate.** → **Manage** → **Browse local files**.
   It's the folder with `Skate.exe` and `ReSkateLauncher.exe` in it.
4. Copy **`ReSkate.dll`** and the **`YourMusic`** folder from the zip into that folder (**not** into
   `Mods`). When Windows asks, choose **Replace the file in the destination**. Your Music lives inside
   `ReSkate.dll` because normal mods can only add things like songs, maps and outfits, and can't talk to
   Spotify or Apple Music.
5. Open the `YourMusic` folder and double-click **`Install Your Music.bat`**. Wait until it says
   **Done**. It builds the "Your Music" playlist mod into your `Mods` folder (the first time it downloads
   ffmpeg, about 100 MB), turns off the ReSkate launcher's own updates (Your Music does ReSkate's updates
   from now on), and sets up the automatic updater.
6. Start **`ReSkateLauncher.exe`** and press **PLAY**. A note in the top-left corner should say
   **"ReSkate …-yourmusic… loaded"**. That means Your Music is running.

## How to use it

1. Open Spotify or Apple Music and play a song.
2. In the game, open the music screen and pick **Your Music**.
3. Your music plays. Use the game's skip button to skip songs. Pick a game playlist to switch back.

In the ReSkate menu (**Insert** → **SETTINGS** → **YOUR MUSIC**) you can see which app it's controlling
and turn the song pop-ups on or off.

If something isn't working, the file `logs\ReSkate.log` in your skate. folder shows what happened.

## Automatic updates

Every hour, while skate. isn't running, Your Music checks this page for a new release and installs it:
a new `ReSkate.dll`, the matching official ReSkate launcher, and a rebuilt playlist mod after skate.
updates. Every download is checked against its published checksum first. It shows up in Windows Task
Scheduler as **Your Music for ReSkate updater**, and writes what it did to `YourMusic\update.log`.

New releases appear on their own: a GitHub robot checks for new ReSkate versions every few hours, adds
Your Music to them, and publishes the result
([follow-reskate](.github/workflows/follow-reskate.yml), [build](.github/workflows/your-music.yml)).

## How to uninstall

Double-click `YourMusic\Uninstall Your Music.bat`, start the ReSkate launcher once (it puts the normal
`ReSkate.dll` back), then delete the `YourMusic` folder.

## How it works

Spotify and Apple Music protect their songs, so no mod can play them through the game itself. Instead,
your music app plays them as normal, and Your Music works the controls:

- A tiny mod adds a **silent** 20-minute song and the "Your Music" playlist to the game.
- When the game starts that silent song, ReSkate tells your music app to play (through Windows' own
  media controls, the same ones your keyboard's play/pause keys use). When the game switches to any
  other song, it tells your app to pause. Pressing skip in the game skips in your app.

The code lives in `Extension/YourMusic/`, with small hooks in three ReSkate files. The installer, updater
and uninstaller are in `contrib/your-music/package/`, and the design and plans in
[`contrib/your-music/`](contrib/your-music/). To build it yourself, follow ReSkate's
[building instructions](https://github.com/Dingo-Shenanigans/ReSkate#building-from-source).

## Credits

- **skate.** is developed by **Full Circle** and published by **Electronic Arts**. The game and
  everything in it belong to EA. You need your own copy on Steam.
- **[ReSkate](https://github.com/Dingo-Shenanigans/ReSkate)** is made by **the ReSkate contributors**
  (Dingo Shenanigans). Your Music is built on top of their work: the launcher, the runtime that loads into
  the game, the mod loader, and the music-screen features that make the Your Music playlist possible.
  This repository is a copy (fork) of ReSkate with Your Music added. Thank you!
- **[ReSkateMusicPacker](https://github.com/DeckardDetribine/ReSkateMusicPacker)** by
  **DeckardDetribine** builds the silent placeholder song into a real skate. music mod.
- ReSkate's third-party libraries (Dear ImGui, Microsoft Detours, RapidJSON, spdlog, SQLite and others)
  and fonts keep their own licenses; they're listed in ReSkate's
  [External/README.md](External/README.md) and included in `licenses/` in every download.
- Your Music by **[JackachuYT](https://github.com/JackachuYT)**, written with help from Claude
  (Anthropic).

## License

Your Music and ReSkate are free software under the [GNU General Public License, version 3](LICENSE).
If you share a modified version, share its source code under the same license. The license covers the
code only, not skate. or anything from it.
