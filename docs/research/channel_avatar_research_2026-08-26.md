# FinReels channel-avatar research

## Source and method

FinReels now uses the official YouTube channel page for each already-verified channel ID. The retrieval script reads the page's public `og:image`/`image_src` metadata and stores only the HTTPS `yt3.googleusercontent.com` or `yt3.ggpht.com` image URL. The official YouTube Data API documentation identifies `snippet.thumbnails` as the supported channel-thumbnail field and documents `default`, `medium`, and `high` channel image sizes.

The reproducible script is `tool/fetch_channel_avatars.py`. Its output is stored in `docs/research/channel_avatar_manifest_2026-08-26.json`, while the application lookup table is `lib/data/channel_avatar_data.dart`.

## Coverage

The deduplicated corpus contains 478 channel IDs from the hardcoded general channels and category resource JSON files. After correcting the stale School of Life channel identity and retrying handle pages, official avatar URLs were resolved for all 478 channels.

## UI integration

The shared `ChannelAvatar` widget is used in category channel tiles, channel-page headers, video-player channel metadata, and notification rows. Images are cached with bounded memory dimensions, clipped to a circle, and fall back to branded initials if the network image is unavailable, removed, rate-limited, or absent.

## References

1. [YouTube Data API: Channels](https://developers.google.com/youtube/v3/docs/channels), especially `snippet.thumbnails`.
2. [YouTube Data API: Thumbnails](https://developers.google.com/youtube/v3/docs/thumbnails), including channel-thumbnail dimensions and HTTPS guidance.
