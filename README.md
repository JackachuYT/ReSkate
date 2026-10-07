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
- **[ReSkate](https://github.com/Dingo-Shenanigans/ReSkate) 1.1.5** already working on it.
- **Spotify** or **Apple Music** (the Windows app), or any other music app.

## How to install

The download only has two things: a **`ReSkate.dll`** (your normal ReSkate 1.1.5 with Your Music built
in) and a **`YourMusic`** folder. Your Music has to replace ReSkate's `ReSkate.dll` because normal mods
can only add things like songs, maps and outfits, and can't talk to Spotify or Apple Music.

1. Download `ReSkate-YourMusic.zip` from **[Releases](https://github.com/JackachuYT/ReSkate/releases)**.
2. Open the ReSkate launcher, go to **SETTINGS** → **ADVANCED**, and turn **off**
   **Install ReSkate updates**. If it's on, the launcher puts the normal `ReSkate.dll` back every time it
   starts. Then close the launcher.
3. Open your skate. folder: in Steam, right-click **skate.** → **Manage** → **Browse local files**.
   It's the folder with `Skate.exe` and `ReSkateLauncher.exe` in it.
4. Copy **`ReSkate.dll`** and the **`YourMusic`** folder from the zip into that folder (**not** into
   `Mods`). When Windows asks, choose **Replace the file in the destination**.
5. Open the `YourMusic` folder and double-click **`Install Your Music.bat`**. Wait until it says
   **Done**. The first time, it downloads ffmpeg (about 100 MB), which it needs to build the mod. It puts
   the "Your Music" playlist mod into your `Mods` folder for you.
6. Start **`ReSkateLauncher.exe`**. Open **MODS**, make sure **YourMusic** is turned on, and press
   **PLAY**. A note in the top-left corner should say **"ReSkate loaded (development build)"**. That means
   Your Music is running.

Run `Install Your Music.bat` again whenever skate. updates.

## How to use it

1. Open Spotify or Apple Music and play a song.
2. In the game, open the music screen and pick **Your Music**.
3. Your music plays. Use the game's skip button to skip songs. Pick a game playlist to switch back.

In the ReSkate menu (**Insert** → **SETTINGS** → **YOUR MUSIC**) you can see which app it's controlling
and turn the song pop-ups on or off.

If something isn't working, the file `logs\ReSkate.log` in your skate. folder shows what happened.

## How to uninstall

In the ReSkate launcher, turn **Install ReSkate updates** back on and start it once; it puts the normal
`ReSkate.dll` back. Then delete the `YourMusic` folder and `Mods\YourMusic`.

## How it works

Spotify and Apple Music protect their songs, so no mod can play them through the game itself. Instead,
your music app plays them as normal, and Your Music works the controls:

- A tiny mod adds a **silent** 20-minute song and the "Your Music" playlist to the game.
- When the game starts that silent song, ReSkate tells your music app to play (through Windows' own
  media controls, the same ones your keyboard's play/pause keys use). When the game switches to any
  other song, it tells your app to pause. Pressing skip in the game skips in your app.

The code lives in `Extension/YourMusic/`, with small hooks in three ReSkate files. The design and plans
are in [`contrib/your-music/`](contrib/your-music/). GitHub builds every release
([workflow](.github/workflows/your-music.yml)). To build it yourself, follow ReSkate's
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
