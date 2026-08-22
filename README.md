# Omarchy Podcast

An Omarchy shell plugin for subscribing to RSS or Atom podcast feeds and
streaming episodes through a detached `mpv` process.

## Features

- Add and remove feeds from the bar popup.
- Browse, filter, and play the newest 100 episodes per feed.
- Resume episodes from their last saved position.
- Seek by 30 seconds from the bar, popup, or keyboard.
- Keep playback alive when `omarchy-shell` restarts.
- Advertise playback through `mpv-mpris` when it is installed.

The plugin streams enclosure URLs. It does not download episodes for offline
playback.

## Install

The plugin is designed for a local Omarchy installation:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/marcelo.podcast
omarchy shell shell rescanPlugins
omarchy plugin enable marcelo.podcast --section right
omarchy restart shell
```

`mpv` is required for playback. The feed parser uses only the Python standard
library and accepts HTTP and HTTPS feeds.

## Controls

- Left-click the bar widget: play or pause.
- Right-click the bar widget: open the library.
- Middle-click the bar widget: play the next episode.
- Mouse wheel over the bar widget: seek by 30 seconds.
- In the popup, `1` and `2` switch between the Episodes and Podcasts tabs,
  `j` and `k` select episodes, `Enter` plays, `h` and `l` seek, `r`
  refreshes, and `/` focuses search.
- Clicking a podcast in the Podcasts tab filters the Episodes tab to that
  show; "Show all episodes" clears the filter.

Subscriptions and progress are stored in:

```text
~/.local/state/marcelo.podcast/library.json
```

The plugin runs as unsandboxed code inside `omarchy-shell`; only add feed URLs
you trust.
