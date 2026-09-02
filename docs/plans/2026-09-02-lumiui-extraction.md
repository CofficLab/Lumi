# LumiUI Extraction Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extract `Packages/LumiUI` into the standalone `CofficLab/LumiUI` Swift Package and switch Lumi to consume it from GitHub.

**Architecture:** The standalone repository contains the existing LumiUI sources, resources, tests, package metadata, and license. LumiUI has no dependency on a parent checkout: its small localization runtime is included in the package, while the Lumi application and sibling packages continue to own their existing local dependencies. The main Lumi repository replaces each `../LumiUI` package path dependency with the GitHub package URL and a semver lower bound.

**Tech Stack:** Swift 6, Swift Package Manager, SwiftUI, macOS 14+, iOS 17+, GitHub CLI.

---

### Task 1: Prepare the standalone package

Extract the tracked `Packages/LumiUI` files to the standalone repository. Remove the `../KitLocalization` dependency and embed its Foundation-only localization runtime so a fresh clone resolves without the Lumi monorepo. Update installation examples and package structure documentation, and add the documented MIT license and CI workflow.

### Task 2: Verify package isolation

Run `swift package dump-package` and `swift test` from the standalone repository. Confirm `Package.swift` contains no parent-relative dependencies and that generated build output remains ignored.

### Task 3: Publish the standalone repository

Create `CofficLab/LumiUI`, commit the package, push `main`, create the annotated `1.0.0` tag and release, then publish the `1.0.1` patch release after resolving the localization type-name collision with clients that also import `KitLocalization`.

### Task 4: Switch Lumi to the remote package

Replace all 88 `../LumiUI` path declarations in tracked `Packages/*/Package.swift` files with `https://github.com/CofficLab/LumiUI.git` dependencies using `from: "1.0.1"`. Remove the in-tree package, update the shared `Package.resolved` pin, and preserve all unrelated working-tree changes.

### Task 5: Verify integration and handoff

Run representative manifest validation and the full Xcode Debug build with automatic package resolution disabled. Review the final diff and status to ensure only LumiUI integration files are staged, then report the GitHub URL, releases, and verification results.
