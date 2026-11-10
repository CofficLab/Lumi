# LumiBookletMaker Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a versioned Swift package that shares Booklet Maker business logic between Lumi and GameFactory without coupling the core to either application's Kernel or UI assembly.

**Architecture:** Start with a pure `BookletMakerCore` target containing public value types and deterministic planning algorithms. Add PDF services, shared UI, and optional Agent integration as separate targets only after the two host applications agree on their APIs. Keep plugin lifecycle and app-specific feature registration in each host repository.

**Tech Stack:** Swift 6, Swift Package Manager, Foundation, CoreGraphics, macOS 14+, iOS 17+, Swift Testing.

---

### Task 1: Establish the standalone package

**Files:**
- Create: `Package.swift`
- Create: `.gitignore`
- Create: `README.md`
- Create: `docs/plans/2026-09-28-lumibookletmaker-plan.md`

**Steps:**

1. Define the `BookletMakerCore` library product and test target.
2. Keep the first target free of Kernel, Provider, SwiftUI, and resource-bundle dependencies.
3. Document the extraction boundary and future target layout.

### Task 2: Extract shared domain models

**Files:**
- Create: `Sources/BookletMakerCore/Models/BookletSettings.swift`
- Create: `Sources/BookletMakerCore/Models/LayoutMode.swift`
- Create: `Sources/BookletMakerCore/Models/OutputSheet.swift`
- Create: `Sources/BookletMakerCore/Models/PaperSize.swift`

**Steps:**

1. Make the shared models public and Codable/Sendable where appropriate.
2. Preserve GameFactory's signature-fold model while keeping simple-pair and booklet-fold compatibility.
3. Keep user-facing localization out of the core; expose stable raw values and host-localized display names later.

### Task 3: Extract deterministic planning algorithms

**Files:**
- Create: `Sources/BookletMakerCore/BookletLayoutEngine.swift`
- Create: `Sources/BookletMakerCore/PDFSplitPlan.swift`

**Steps:**

1. Implement padding, booklet imposition, signature planning, physical-sheet grouping, and display geometry.
2. Implement split-point parsing and segment generation without filesystem or UI dependencies.
3. Keep all public methods deterministic so both applications can share the same tests.

### Task 4: Add core regression tests

**Files:**
- Create: `Tests/BookletMakerCoreTests/BookletLayoutEngineTests.swift`
- Create: `Tests/BookletMakerCoreTests/PDFSplitPlanTests.swift`

**Steps:**

1. Cover four- and eight-page booklet mappings.
2. Cover signature padding and page preservation.
3. Cover invalid/duplicate split points and segment generation.
4. Run `swift test` and commit the initial package.

### Task 5: Integrate the two hosts

**Files:**
- Modify: Lumi's `Packages/PluginBookletMaker/Package.swift`
- Modify: GameFactory's `Packages/PluginBookletMaker/Package.swift`
- Modify: host-specific models and services after API reconciliation

**Steps:**

1. Add the released `LumiBookletMaker` package as a dependency in each host.
2. Replace duplicated core models and planners with imports from `BookletMakerCore`.
3. Keep host-specific plugin lifecycle, Agent/Skill registration, toolbar variants, and localization adapters local.
4. Run both package test suites before publishing a versioned release.
