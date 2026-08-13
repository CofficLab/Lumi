# BookletMaker Multiplatform App Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Merge the native macOS and iOS BookletMaker products into one Xcode app target with the shared bundle identifier `com.coffic.bookletmaker`.

**Architecture:** Keep the existing platform-native factories and user interfaces, but select them from one conditionally compiled SwiftUI app entry point. Configure one Xcode target and scheme for macOS, iPhone, and iPad, with platform-filtered package products and platform-specific build settings.

**Tech Stack:** SwiftUI, Xcode multiplatform targets, Swift Package Manager, xcconfig.

---

### Task 1: Create one platform-selecting app entry point

**Files:**
- Modify: `BookletMakerApp/BookletMakerApp.swift`
- Delete: `BookletMakeriOSApp/BookletMakeriOSApp.swift`

1. Keep the existing macOS scene behind `#if os(macOS)`.
2. Move the iOS application delegate and mobile scene into the same source file behind `#if os(iOS)`.
3. Verify that exactly one `@main` declaration is compiled for each destination.

### Task 2: Consolidate product configuration

**Files:**
- Modify: `Config/BookletMaker.xcconfig`
- Delete: `Config/BookletMaker-iOS.xcconfig`
- Modify: `BookletMakerApp/BookletMaker-Info.plist`
- Modify: `BookletMakerApp/Assets.xcassets/AppIcon.appiconset/Contents.json`

1. Declare macOS, iOS device, and iOS Simulator as supported platforms.
2. Use `com.coffic.bookletmaker` on every platform.
3. Preserve macOS sandbox and window behavior while supplying iOS launch-screen, device-family, and run-path settings conditionally.
4. Add an iOS app-icon entry to the BookletMaker asset catalog.

### Task 3: Collapse the Xcode project to one target and scheme

**Files:**
- Modify: `Lumi.xcodeproj/project.pbxproj`
- Delete: `Lumi.xcodeproj/xcshareddata/xcschemes/BookletMaker-iOS.xcscheme`

1. Add `FactoryBookletMakerMobile` to the BookletMaker target for iOS only.
2. Restrict `FactoryCore` and `FactoryBookletMaker` to macOS builds.
3. Remove the legacy `BookletMaker-iOS` target, product, configurations, and source group.
4. Keep the shared `BookletMaker` scheme as the only product scheme.

### Task 4: Verify all supported destinations

**Files:**
- Verify: `Lumi.xcodeproj`

1. Inspect resolved build settings for macOS and iOS and confirm the bundle identifier matches.
2. Build `BookletMaker` for macOS without signing.
3. Build `BookletMaker` for a generic iOS Simulator destination without signing.
4. Confirm the scheme list contains only one BookletMaker app entry.
