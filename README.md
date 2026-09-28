# Pending GMSTileLayer requests delay local tiles

A standalone reproduction for Maps SDK for iOS **10.15.0**, using UIKit and a direct `GMSTileLayer` subclass. No application code, real map tiles, tile server, or HTTP tile requests are used.

The question under investigation is whether pending asynchronous tile requests prevent the SDK from issuing further requests, including for tiles that can be returned immediately from local storage.

## Build and run

1. Open `TilePending.xcodeproj` in Xcode. Swift Package Manager resolves GoogleMaps at exactly **10.15.0**.
2. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set `MAPS_API_KEY` to your own Maps SDK for iOS key. The local file is ignored by git. Without a key, the app builds and displays setup instructions.
3. For a physical device, set your development team and a unique bundle identifier in `Local.xcconfig`, or in Xcode's Signing & Capabilities. If your Maps key has iOS application restrictions, allow the bundle identifier you use.
4. Select an iPhone Simulator or device and run the `TilePending` scheme. Choose a case, then tap **Start** at the bottom of the screen. The default selection is **Mixed · 45s**; opening the app does not start the test.

The deployment target is iOS 16.0. This project was built with Xcode 27.0. Google Maps initialization still requires an API key; only tile retrieval is simulated.

The app uses `UIWindowScene` and a scene delegate, including on iOS 27. The initial revision's legacy app lifecycle crashed at launch on iOS 27; this has been corrected and verified on an iPhone 17 Pro running iOS 27.0.

## Reproduce

- Select **Mixed · 45s**, tap **Start**, and leave the app in the foreground for at least 50 seconds. Green tiles are saved PNGs. Orange tiles are generated images delivered after a nonblocking 45-second delay **from each request**. A missing tile first requested around 45s therefore completes around 90s.
- Watch the request/return/pending counters. Check whether some green areas appear only after delayed completions begin, even though those green images existed before the map was attached.
- Compare with **All local** and **Mixed · 0s**. The latter uses the same checkerboard and orange images but responds immediately.
- Use **Share log** to export timestamped `REQUEST`, `DELIVER`, `WAIT_BEGIN`, and `WAIT_END` events. Logs are also in the app's Documents folder.

The selector and Start button are disabled while requests remain pending. Once requests have finished, choose a case and tap Start again to create a fresh map and tile layer. More missing tiles can be requested after the first 45-second batch, so completing the entire view can take several batches. For independent comparisons, terminate and relaunch the app for each case. In Xcode's scheme, an optional launch argument (`mixed`, `baseline`, or `immediate`) preselects the case; tap Start to begin. Switching the selector after completion is useful for a quick visual comparison, but the recorded evidence uses fresh processes.

Expected: local tiles can be requested and delivered while other requests remain pending. The behavior being investigated: later requests for local tiles arrive only after delayed requests complete.

## What the sample does

- One `GMSMapView`, `mapType = .none`, one custom tile layer with `tileSize = 256`.
- Fixed camera at latitude 36.72, longitude 138.5, zoom 16. Gestures are disabled to keep comparisons at the same position.
- Generated 256px parent images at zoom 16, saved in a temporary directory before attaching the layer. In mixed cases, `(parentX + parentY) % 2 == 0` parents are local.
- Requests above zoom 16 crop the corresponding parent image. The SDK's requested zoom is recorded, not forced to 18.
- Missing parents get one asynchronous completion per SDK request. There is no application concurrency cap, semaphore, network connection pool, or blocking sleep. Multiple requests for the same parent can be pending at once.
- Completed delayed parents are cached in memory. Each case starts with a new temporary directory and empty cache.

The sample deliberately preserves parent-tile cropping from the original report. It does not assume that 16 is a documented SDK limit, or that a queue is shared across layers. Request totals can vary with viewport, screen scale, OS, and SDK.

## Files

- `ReproTileLayer.swift`: generated images, local reads, asynchronous delay, event logging.
- `ReproViewController.swift`: fixed map, case selector, counters, log export.
- `AppDelegate.swift`: API-key setup and app entry point.

## Recorded result

Before the bottom Start button was added, on iPhone 17 Pro Simulator / iOS 26.5, the standalone sample reproduced a pause at **31 requests, 15 deliveries, and 16 pending requests**. The first delayed completion occurred at 45.857s. A local tile was first requested at 45.899s and delivered at 45.899s. All-local and immediate-response controls each completed 84 requests within the first few seconds. The Start button reduces the map viewport, so current request totals can differ.

See [logs, screenshots, and measurement details](evidence/README.md). These are measurements of this sample, not copied timings from the original application harness.

After the scene-lifecycle fix, the same 31-request / 15-delivery / 16-pending pause was also recorded on a physical iPhone 17 Pro running iOS 27.0. The first delayed completion occurred at 45.413s, followed by newly issued requests for local tiles.

No API key, signing team, provisioning profile, build product, or private application dependency is included in the repository. Do not distribute your locally built app binary, which contains your configured key.
