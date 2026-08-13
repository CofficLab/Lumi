# Booklet Maker iOS UI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the macOS-shaped Booklet Maker interface on iOS with an adaptive, task-focused iPhone and iPad experience.

**Architecture:** Keep the existing PDF processing view model and macOS views unchanged. `FactoryBookletMakerMobile` directly owns kernel startup and the BookletMaker-specific iOS shell; there is no shared mobile UI factory. Add an iOS-only workspace that owns file importing, tool switching, settings presentation, progress feedback, and export actions; switch between a compact bottom-action layout and a regular-width split layout through SwiftUI size classes.

**Tech Stack:** SwiftUI, UniformTypeIdentifiers, existing BookletMaker view model and PDF rendering services.

---

### Task 1: Add the adaptive iOS workspace

**Files:**
- Create: `Plugins/BookletMakerPlugin/Sources/Views/Mobile/BookletMakerMobileView.swift`
- Modify: `Plugins/BookletMakerPlugin/Sources/BookletMakerPlugin.swift`

**Steps:**
1. Add a shared mobile navigation shell with file importer and document menu.
2. Add a compact iPhone layout with a bottom settings/export action bar.
3. Add a regular-width iPad layout with a persistent tool sidebar and settings inspector.
4. Keep the existing macOS view and rail contributions behind platform checks.

### Task 2: Add native mobile tool content and settings

**Files:**
- Create: `Plugins/BookletMakerPlugin/Sources/Views/Mobile/BookletMakerMobileSettingsView.swift`
- Create: `Plugins/BookletMakerPlugin/Sources/Views/Mobile/PDFSplitMobileView.swift`
- Create: `Plugins/BookletMakerPlugin/Sources/Views/Mobile/BookletPreviewMobileView.swift`

**Steps:**
1. Build settings with Form sections and accessible controls.
2. Build a touch-friendly split-point editor with large gap buttons and editable results.
3. Build a responsive booklet preview with stage selection and summary information.
4. Cover loading, invalid input, progress, success, and error states.

### Task 3: Verify on iPhone and iPad

**Files:**
- Verify: `Lumi.xcodeproj`

**Steps:**
1. Build the `BookletMaker-iOS` scheme for an iPhone simulator.
2. Launch and inspect the iPhone compact layout.
3. Launch and inspect the iPad regular-width layout.
4. Run Booklet Maker package tests where the repository test target permits.
