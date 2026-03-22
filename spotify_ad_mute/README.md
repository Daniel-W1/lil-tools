# Spotify Mute

`spotify-mute` is a tiny macOS-only AppleScript watcher that uses the Spotify desktop app as the source of truth.

It is designed for personal use, but the repo is structured so other people can clone it, edit `blacklist.tsv`, and run it without needing Spotify OAuth, API tokens, or app registration.

## What it does

- reads the current track title, artist, album, and player state from Spotify via AppleScript
- also reads the track `id` and `spotify url` so it can spot likely ad content
- checks those values against a blacklist file
- auto-mutes likely Spotify ads based on ad-like metadata
- mutes system output via AppleScript when the current track matches
- restores audio when playback moves to a non-matching track, but only if this script was the thing that muted audio

## Project layout

- `spotify_muter.applescript`: main watcher loop
- `blacklist.tsv`: sample blacklist entries
- `inspect_spotify_track.applescript`: prints the currently playing Spotify metadata
- `start_spotify_muter.sh`: wrapper used by `launchd`
- `install_launch_agent.sh`: installs the startup agent for the current clone path
- `uninstall_launch_agent.sh`: removes the startup agent
- `launchd/local.spotify-mute.plist.template`: generic LaunchAgent template

## Requirements

- macOS
- Spotify desktop app
- permission for `osascript` to control Spotify when macOS prompts

## Blacklist format

Use tab-separated columns:

```text
title<TAB>artist<TAB>album
```

Rules:

- title, artist, and album are all optional, but at least one field must be filled
- blank artist/album fields are treated as wildcards
- matching is case-insensitive
- matching uses substring containment, so `Intro` matches `Daily Intro Mix`

## Ad detection

The watcher also auto-mutes likely ads without needing a blacklist entry.

It treats a track as an ad when one of these metadata checks matches:

- track `id` contains `spotify:ad`
- track `spotify url` contains `spotify:ad`
- track title, artist, or album contains `Advertisement`
- artist is `Spotify` and title/album contains `upgrade` or `premium`

These are heuristics based on the metadata exposed by the Spotify desktop app, not a documented AppleScript `is ad` flag.

Examples:

```text
Bad Song
Podcast Intro	Some Creator
Live Version	Artist Name	Tour Album
Better Now	Post Malone
```

## Run it

From this folder:

```bash
osascript spotify_muter.applescript
```

Or pass a custom blacklist file:

```bash
osascript spotify_muter.applescript /absolute/path/to/blacklist.tsv
```

Stop it with `Ctrl+C`.

## Test it

The sample blacklist already includes:

```text
Better Now	Post Malone
```

So a quick manual test is:

1. Start the watcher with `osascript spotify_muter.applescript`
2. Play `Better Now` in Spotify
3. Confirm your Mac mutes within about one second
4. Skip to another track and confirm audio returns

To inspect the current Spotify metadata while something is playing:

```bash
osascript inspect_spotify_track.applescript
```

That helper prints the current `name`, `artist`, `album`, `id`, and `spotify url`, which is useful for confirming blacklist entries and for seeing what ad metadata Spotify exposes on your machine.

## Start at login

The macOS-native way to keep this running at startup is a per-user `launchd` agent.

Install it for the current clone with:

```bash
chmod +x start_spotify_muter.sh install_launch_agent.sh uninstall_launch_agent.sh
./install_launch_agent.sh
```

Useful commands:

```bash
launchctl print gui/$(id -u)/local.spotify-mute
tail -f ~/Library/Logs/spotify-mute.log
./uninstall_launch_agent.sh
```

Notes:

- this starts when you log into macOS, not before login
- the first automated run may still trigger macOS permission prompts for controlling Spotify
- if you move this repo, rerun `./install_launch_agent.sh` so the generated plist points at the new path

## macOS permissions

The first run may prompt you to allow `osascript` to control Spotify. Approve that so Apple Events can read the track metadata.
