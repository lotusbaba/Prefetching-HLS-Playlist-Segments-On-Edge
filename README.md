# Various ways of Prefetching HLS Segments on the Fastly Edge

Prerequisite - VCL, Fastly, CDN, HTTP, Javascript, Rust, Media Playlist structure.


## Features

- Works on HLS manifest playlists
- Prefetches different number of segments depending on the solution (client based or edge based), language, and cache (Varnish vs. C@E)
- May modify the playlist sent to the client (C@E version)
- Doesn't always use Fastly shielding so if you need shielding please use the VCL appraches in the repo


