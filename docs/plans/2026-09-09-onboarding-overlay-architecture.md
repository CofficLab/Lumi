# Onboarding Overlay Architecture

## Goal

Move onboarding presentation and completion persistence out of `LumiApp` and the
provider factory. `RootViewProviding` should render registered overlays
reactively; `OnboardingProviding` should collect pages and expose presentation
state; `PluginOnboarding` should register the provider, render the overlay, and
persist completion on disk.

## Design

- `DefaultRootViewProvider.makeRootView()` returns an observing overlay host.
  Adding or removing an overlay after the root view was assembled therefore
  updates the existing view tree.
- `DefaultOnboardingProviding` owns page collection and transient presentation
  state (`show` / `dismiss`). It remains independent from persistence.
- `OnboardingPlugin` creates and registers the onboarding provider during
  `onBoot`, registers the root overlay, and stores a completion marker under
  its `StorageProviding` plugin directory.
- The onboarding UI and its notification bridge live in `PluginOnboarding`.
- `LumiApp` only consumes the root view and toast host. `ProviderFactory` no
  longer constructs onboarding providers.

The existing `DefaultPluginFactory` remains the application's static plugin
composition root. Removing that final compile-time catalog dependency would
require a separate plugin discovery/registration design and is outside this
focused lifecycle refactor.

## Verification

1. Run `swift test` for `ProviderOnboarding`, `ProviderRootView`, and
   `PluginOnboarding`.
2. Build the macOS Lumi scheme without code signing.
3. Confirm the worktree contains no changes to the user's unrelated resource
   files.
