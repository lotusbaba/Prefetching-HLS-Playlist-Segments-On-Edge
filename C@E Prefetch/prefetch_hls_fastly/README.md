# Compute@Edge App for Prefetching HLS Segment in Rust

Get to know the Fastly Compute@Edge environment with a basic starter that demonstrates routing, simple synthetic responses, and overriding caching rules.

**For more details about this and other starter kits for Compute@Edge, see the [Fastly Developer Hub](https://developer.fastly.com/solutions/starters/)**.

## Features

- Works on HLS manifest playlists
- Prefetches 5 segments by default
- Modifies the playlist sent to the client
- Doesn't use Fastly shielding since it's a C@E app

