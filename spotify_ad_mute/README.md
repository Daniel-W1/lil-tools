# Spotify Mute

`spotify-mute` is a small macOS AppleScript watcher for the Spotify desktop app. It polls Spotify once per second, mutes your Mac when the current item looks like an ad or matches your blacklist, and restores audio when playback returns to something allowed.

It does not use the Spotify API, OAuth, tokens, or app registration. Everything runs locally through AppleScript.

## What it does

- reads the current track title, artist, album, player state, `id`, and `spotify url`
- auto-mutes likely Spotify ads based on metadata heuristics
- supports a simple TSV blacklist for tracks, podcast intros, or albums you want muted
- restores audio only if this script was the thing that muted it
- can run in the foreground or as a per-user `launchd` agent at login

## Requirements

- macOS
- Spotify desktop app
- permission for `osascript` to control Spotify when macOS prompts

## Project layout

- `spotify_muter.applescript`: main watcher loop
- `blacklist.tsv`: sample blacklist entries
- `inspect_spotify_track.applescript`: prints the currently playing Spotify metadata
- `start_spotify_muter.sh`: wrapper script used by `launchd`
- `install_launch_agent.sh`: installs the LaunchAgent for the current clone path
- `uninstall_launch_agent.sh`: unloads and removes the LaunchAgent
- `launchd/local.spotify-mute.plist.template`: LaunchAgent template used during install

## Quick start

From this folder:

```bash
osascript spotify_muter.applescript
```

Or pass a custom blacklist file:

```bash
osascript spotify_muter.applescript /absolute/path/to/blacklist.tsv
```

Stop it with `Ctrl+C`.

## Blacklist format

Use tab-separated columns:

```text
title<TAB>artist<TAB>album
```

Rules:

- title, artist, and album are all optional, but at least one field must be filled
- blank fields behave as wildcards
- matching is case-insensitive
- matching uses substring containment, so `Intro` matches `Daily Intro Mix`
- lines starting with `#` are treated as comments

Current sample entries in `blacklist.tsv`:

```text
Bad Song
Podcast Intro	Some Creator
Live Version	Artist Name	Tour Album
```

## Ad detection

The watcher also auto-mutes likely ads without needing a blacklist entry.

It treats a track as ad-like when one of these checks matches:

- track `id` contains `spotify:ad`
- track `spotify url` contains `spotify:ad`
- track title, artist, or album contains `Advertisement`
- artist is `Spotify` and title or album contains `upgrade` or `premium`

These are heuristics based on metadata exposed by the Spotify desktop app, not a documented AppleScript `is ad` flag.

## Inspect current metadata

To inspect the exact Spotify metadata for the currently playing item:

```bash
osascript inspect_spotify_track.applescript
```

That helper prints `player_state`, `name`, `artist`, `album`, `id`, and `spotify_url`. It is useful for creating blacklist entries and checking how Spotify labels ad content on your machine.

## Manual testing

A quick manual test with the sample blacklist:

1. Start the watcher with `osascript spotify_muter.applescript`.
2. In Spotify, play something whose metadata matches one of the sample rows, or temporarily add your own known track to `blacklist.tsv`.
3. Confirm your Mac mutes within about one second.
4. Skip to a non-matching track and confirm audio returns.

## Start at login

To run this automatically after you log into macOS:

```bash
chmod +x start_spotify_muter.sh install_launch_agent.sh uninstall_launch_agent.sh
./install_launch_agent.sh
```

The installer generates `~/Library/LaunchAgents/local.spotify-mute.plist`, points it at the current repo path, enables it, and starts it immediately.

Useful commands:

```bash
launchctl print gui/$(id -u)/local.spotify-mute
tail -f ~/Library/Logs/spotify-mute.log
./uninstall_launch_agent.sh
```

Notes:

- this starts when you log into macOS, not before login
- the agent is configured with `KeepAlive`, so `launchd` restarts it if it exits
- if you move this repo, rerun `./install_launch_agent.sh` so the generated plist uses the new path
- the first automated run may still trigger macOS permission prompts for controlling Spotify

## macOS permissions

On first use, macOS may ask you to allow `osascript` to control Spotify. Approve that prompt so the watcher can read track metadata and respond to playback changes.
