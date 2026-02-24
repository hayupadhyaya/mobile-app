# CarPlay Integration

## Architecture

CarPlay uses a single `CPListTemplate` as root (not `CPTabBarTemplate`) with two sections:

```
Root: CPListTemplate ("Library")
├── Section 1: Browse (CPListImageRowItem)
│   ├── Albums       → push CPListTemplate (album list)
│   ├── Playlists    → push CPListTemplate (playlist list)
│   ├── Audiobooks   → push CPListTemplate (audiobook list)
│   └── Radio        → push CPListTemplate (radio station list)
└── Section 2: "Recently Played" (CPListSection, async loaded)
    └── CPListItems (last played tracks/items)
```

### Template Constraints (iOS 18+)

- `CPTabBarTemplate` only accepts `CPListTemplate` and `CPGridTemplate` — NOT `CPSearchTemplate`
- `CPSearchTemplate` cannot be pushed onto navigation stack either
- Only these templates can be pushed: `CPListTemplate`, `CPGridTemplate`, `CPNowPlayingTemplate`, `CPAlertTemplate`, `CPActionSheetTemplate`, `CPVoiceControlTemplate`
- Search is available via Siri voice commands for CarPlay audio apps

### Browse Icons

The browse row uses `CPListImageRowItem` with custom-rendered images:
- Background color: `#404378` (Material3 `primaryContainer` dark theme)
- Icon tint: `#C0C1FF` (Material3 `primary` dark theme)
- Icons match `LandingPage.kt` `LibraryRow`: Album, FeaturedPlayList, MenuBook, Radio
- Images are rendered at `CPListImageRowItem.maximumImageSize` — fill entire rect, let CarPlay handle corner rounding

## Files

| File | Purpose |
|------|---------|
| `iosApp/iosApp/CarPlay/CarPlaySceneDelegate.swift` | Scene delegate, template creation, navigation |
| `iosApp/iosApp/CarPlay/CarPlayContentManager.swift` | Data fetching bridge, maps `AppMediaItem` → `CPListItem` |
| `iosApp/iosApp/iOSApp.swift` | `AppDelegate` for CarPlay scene routing + KMP ready notification |
| `composeApp/src/iosMain/.../KmpHelper.kt` | iOS-only bridge: fetch methods for audiobooks, radio, search |
| `iosApp/iosApp/CarPlay.entitlements` | `com.apple.developer.carplay-audio` entitlement |
| `iosApp/iosApp/Info.plist` | `CPTemplateApplicationSceneSessionRoleApplication` scene config |

## Koin Initialization Timing

CarPlay scene may connect before the main SwiftUI view renders (which triggers `initKoin` via `MainViewController`). The solution:

1. `iOSApp.swift` posts `Notification.Name.kmpReady` when `ContentView` appears
2. `CarPlaySceneDelegate` checks `isKmpReady()` on connect
3. If not ready, observes `.kmpReady` notification and defers template setup

No core/common Kotlin files are modified — the guard is entirely in Swift.

## Item Selection Flow

1. User taps a category → pushes `CPListTemplate` with items from `CarPlayContentManager`
2. User taps an item → `CarPlayContentManager.playItem()` sends play command via `KmpHelper`
3. `CPNowPlayingTemplate.shared` is pushed for playback controls

## Adding New Categories

1. Add fetch method to `KmpHelper.kt` (iosMain only)
2. Add corresponding method to `CarPlayContentManager.swift`
3. Add entry to `categoryIcons` array and handler in `CarPlaySceneDelegate.swift`

## TODO

- [ ] **Artwork for category lists** — Load album/artist/playlist/audiobook artwork from server into `CPListItem` images (albums, artists, playlists, audiobooks). Currently using SF Symbol placeholders. Requires async image loading via `imageInfo.url(serverUrl:)` and setting `CPListItem.setImage()` after download.
- [ ] **Recently Played artwork row** — Display recently played items as a `CPListImageRowItem` (same style as Browse row) with artwork thumbnails and titles, instead of plain `CPListItem` text rows. Each image should be the item's artwork loaded from server.
- [ ] **Now Playing artwork** — Ensure `CPNowPlayingTemplate` displays current track artwork via `MPNowPlayingInfoCenter`
