# Pending tile requests delay saved tiles

We want saved map tiles to remain displayable under poor or unstable network conditions, when requests for missing tiles can stay pending for a long time.

If the app detects that it is offline (for example, in airplane mode), it can immediately report missing tiles as unavailable. The concern here is a connection that appears available while requests remain pending.

This standalone sample uses **Maps SDK for iOS 10.15.0** and a simulated **45-second delay** to reproduce that pending-request state consistently. Tiles are generated locally; no tile server is needed.

## Build and run

1. Open `TilePending.xcodeproj` in Xcode. Swift Package Manager resolves the SDK automatically. Tested with Xcode 27.0; deployment target iOS 16.0.
2. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and enter your own Maps SDK for iOS API key. This file is ignored by git.
3. For a physical device, select your signing team and a unique bundle identifier. Allow that identifier in your API key's iOS restrictions, if configured.
4. Run the app, select **Mixed · 45s**, and tap **Start** at the bottom. Keep the app in the foreground for at least 50 seconds.

## What to look for

**Green tiles are already saved on disk.** Some remain blank until the delayed orange responses arrive, even though the green images could be returned immediately if requested. In the recorded runs, the SDK stopped issuing further requests with **16 requests pending**, then resumed after responses completed.

Compare with **All local** and **Mixed · 0s**. Use **Share log** to export request timings.

The delay is 45 seconds **per request**, so later requests may complete around 90 seconds or later. Controls remain disabled while requests are pending.

See [logs, screenshots, and technical details](evidence/README.md).
