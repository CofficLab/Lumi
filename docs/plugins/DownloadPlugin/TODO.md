# Download Plugin TODO

## Current Verdict
- [ ] Keep the `aria2c + JSON-RPC + native SwiftUI` direction.
- [ ] Treat "Motrix equivalent" as a long-term target, not the v1 scope.
- [ ] Update the original plan after the v1 implementation details are validated.

## Plan Corrections
- [ ] Replace outdated `SuperPlugin.swift` path with `LumiApp/Core/Proto/SuperPlugin.swift`.
- [ ] Remove references to missing `PluginProvider.swift`.
- [ ] Replace `PluginSettingsStore.swift` references with `PluginSettingsVM` and `AppSettingStore`, or add a plugin-local settings store if typed settings are needed.
- [ ] Replace old `GlassCard.swift` path with the current `GlassCard` compatibility/typealias path under `LumiApp/Core/Components/LumiUICompatibility.swift`.
- [ ] Confirm whether status-bar integration should use `addStatusBarLeadingView`, `addStatusBarCenterView`, `addStatusBarTrailingView`, or menu-bar popup contributions.

## V1 Scope
- [ ] Create `LumiApp/Plugins/MotrixDownloadPlugin/`.
- [ ] Add `MotrixDownloadPlugin.swift`.
- [ ] Implement `SuperPlugin` metadata:
  - [ ] `static let shared`
  - [ ] `id`
  - [ ] `displayName`
  - [ ] `description`
  - [ ] `iconName`
  - [ ] `order`
  - [ ] `enable`
  - [ ] `instanceLabel`
- [ ] Add panel entry with `addPanelView(activeIcon:)`.
- [ ] Add settings entry with `addSettingsView()`.
- [ ] Support HTTP/HTTPS downloads first.
- [ ] Support task list display.
- [ ] Support pause, resume, remove, and retry.
- [ ] Support global download speed display.
- [ ] Support default download directory setting.
- [ ] Support global speed limit setting.
- [ ] Support task completion notification.

## Aria2 Runtime
- [ ] Decide resource location for bundled `aria2c`; do not put executable binaries in `.xcassets`.
- [ ] Add `aria2c` as a bundled resource or documented external dependency.
- [ ] On first run, copy bundled `aria2c` to Application Support or another writable plugin directory.
- [ ] Ensure copied `aria2c` has executable permission.
- [ ] Create writable plugin data directory.
- [ ] Store `aria2.session` in the writable plugin data directory.
- [ ] Store task metadata cache in the writable plugin data directory.
- [ ] Stop `aria2c` cleanly when the plugin/app shuts down.
- [ ] Provide fallback to an external `aria2c` path for development.

## RPC Security
- [ ] Bind RPC to `127.0.0.1` only.
- [ ] Avoid a fixed default port when possible; choose an available local port.
- [ ] Generate an RPC secret per service start or persist a secret in plugin settings.
- [ ] Pass the secret to all JSON-RPC requests.
- [ ] Handle port collision and startup failure with a clear UI error state.
- [ ] Do not expose RPC to LAN.

## Models
- [ ] Add `DownloadTask`.
- [ ] Add task status enum mapped from aria2 statuses.
- [ ] Add `TransferStats`.
- [ ] Add error model for RPC and download failures.
- [ ] Defer `TorrentInfo` until BT support starts.

## Services
- [ ] Add `Aria2Service`.
- [ ] Implement aria2 process launch.
- [ ] Implement JSON-RPC client.
- [ ] Implement `aria2.addUri`.
- [ ] Implement `aria2.pause`.
- [ ] Implement `aria2.unpause`.
- [ ] Implement `aria2.remove` or `aria2.forceRemove`.
- [ ] Implement `aria2.tellActive`.
- [ ] Implement `aria2.tellWaiting`.
- [ ] Implement `aria2.tellStopped`.
- [ ] Implement `aria2.getGlobalStat`.
- [ ] Implement polling or event update loop.
- [ ] Add cancellation handling for polling tasks.

## View Model
- [ ] Add `DownloadManagerViewModel`.
- [ ] Keep aria2 calls off the main actor.
- [ ] Publish task snapshots for SwiftUI.
- [ ] Aggregate global speed.
- [ ] Surface startup, permission, and RPC errors.
- [ ] Add user actions for add, pause, resume, remove, and retry.

## UI
- [ ] Add `DownloadManagerView`.
- [ ] Add task row view with name, progress, speed, ETA, and actions.
- [ ] Add empty state.
- [ ] Add add-download flow for URL input.
- [ ] Add detail panel or inspector for errors and connection stats.
- [ ] Add `DownloadSettingsView`.
- [ ] Use existing `GlassCard` and `AppTheme` patterns.
- [ ] Avoid nesting cards inside cards.
- [ ] Verify text does not overflow in compact widths.

## Settings
- [ ] Store `downloadDirectory`.
- [ ] Store `maxConcurrentTasks`.
- [ ] Store `defaultUserAgent`.
- [ ] Store `speedLimitGlobal`.
- [ ] Store external `aria2c` path for development fallback.
- [ ] Defer `enableTrackerAutoUpdate`.
- [ ] Defer `enablePortMapping`.
- [ ] Re-evaluate whether settings belong in `AppSettingStore` or a plugin-local plist/JSON store.

## Tests
- [ ] Add `Tests/MotrixDownloadPluginTests/`.
- [ ] Add plugin metadata smoke test.
- [ ] Add RPC request encoding tests.
- [ ] Add task status mapping tests.
- [ ] Add view-model action tests with a fake aria2 service.
- [ ] Add integration test for add-download flow when `aria2c` is available.
- [ ] Document tests skipped when `aria2c` is missing.

## Packaging And Signing
- [ ] Confirm `aria2c` is included in the app bundle.
- [ ] Confirm `aria2c` is executable after copy.
- [ ] Confirm Apple Silicon binary works locally.
- [ ] Confirm code signing requirements for the embedded executable.
- [ ] Confirm current entitlements are enough for non-sandboxed distribution.
- [ ] If sandboxing is introduced, add user-selected read/write file access and security-scoped bookmarks.

## V2 BT And Magnet
- [ ] Support magnet URI import.
- [ ] Support `.torrent` file import.
- [ ] Add `TorrentInfo`.
- [ ] Add torrent file tree parsing/display.
- [ ] Support selective file download.
- [ ] Add tracker list cache.
- [ ] Add tracker auto-update.
- [ ] Add tracker update failure fallback.

## V3 Advanced Features
- [ ] Add FTP support if still needed.
- [ ] Add per-task speed limit.
- [ ] Add per-task User-Agent override.
- [ ] Add max split/thread controls.
- [ ] Add recent tasks menu-bar popup.
- [ ] Add optional "delete related files" flow.
- [ ] Add UPnP/NAT-PMP only if BT use proves it is worth the complexity.

## Open Questions
- [ ] Should this plugin be enabled by default?
- [ ] Should the panel icon be visible in the main ActivityBar, menu bar only, or both?
- [ ] Should completed tasks be persisted in Lumi or only in aria2 session state?
- [ ] Should downloads outside the default directory require explicit user confirmation?
- [ ] Should BT/Magnet be hidden behind an advanced setting for compliance reasons?
