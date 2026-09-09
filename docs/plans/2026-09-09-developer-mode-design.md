# Runtime Developer Mode

## Goal

Replace compile-time `#if DEBUG` checks used by renderer diagnostics with a
runtime developer-mode switch. The switch is exposed through a provider so
feature plugins can consume the state without depending on the plugin that
owns the toolbar control.

## Architecture

- `ProviderDeveloperMode` defines `DeveloperModeProviding`, the default in-memory
  implementation, and a SwiftUI observation projection.
- `PluginDeveloperMode` registers the provider and contributes a leading global
  toolbar control. The provider defaults to disabled and the plugin is always
  on, so a debug build is no longer required to exercise diagnostics.
- Message list V1/V2/V3 and the core message renderer resolve
  `DeveloperModeProviding` from `KernelCoreContainer`. They render diagnostic
  badges and borders only while `isEnabled` is true.
- If a host does not install the control plugin, consumers treat the provider
  as absent and keep diagnostics disabled.

## State flow

```text
DeveloperModeToggleView
        │ setEnabled / toggle
        ▼
DeveloperModeProviding in KernelCore
        │ `objectWillChange` publisher
        ▼
DeveloperModeObservation
        │ SwiftUI invalidation
        ▼
MessageRowView / ToolCallRowsView
```

## Verification

- Unit-test provider defaults, toggling, observer cancellation, and SwiftUI
  state projection.
- Build the provider, control plugin, three message-list plugins, and core
  message renderer independently.
- Run the provider and affected package tests, then inspect the final diff for
  remaining compile-time guards around renderer badges and borders.
