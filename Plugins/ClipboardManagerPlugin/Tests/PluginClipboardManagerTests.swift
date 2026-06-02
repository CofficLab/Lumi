import AppKit
import SwiftData
import Testing
@testable import ClipboardManagerPlugin

@Test func pluginMetadataIsStable() {
    #expect(ClipboardManagerPlugin.id == "ClipboardManager")
    #expect(ClipboardManagerPlugin.navigationId == "clipboard_manager")
    #expect(ClipboardManagerPlugin.displayName.isEmpty == false)
    #expect(ClipboardManagerPlugin.iconName == "doc.on.clipboard")
    #expect(ClipboardManagerPlugin.category == .general)
}

@MainActor
@Test func writesTextHistoryItemToPasteboard() {
    let pasteboard = NSPasteboard.withUniqueName()
    let item = ClipboardHistoryItem(
        type: ClipboardItemType.text.rawValue,
        content: "Copied from history",
        searchKeywords: "copied from history"
    )

    let didWrite = ClipboardManagerViewModel.write(item, to: pasteboard)

    #expect(didWrite)
    #expect(pasteboard.string(forType: .string) == "Copied from history")
}

@MainActor
@Test func writesImageHistoryItemToPasteboard() throws {
    let imageURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("clipboard-history-\(UUID().uuidString).png")
    defer { try? FileManager.default.removeItem(at: imageURL) }

    try makeTestPNG().write(to: imageURL)

    let pasteboard = NSPasteboard.withUniqueName()
    let item = ClipboardHistoryItem(
        type: ClipboardItemType.image.rawValue,
        content: imageURL.path,
        searchKeywords: imageURL.lastPathComponent
    )

    let didWrite = ClipboardManagerViewModel.write(item, to: pasteboard)

    #expect(didWrite)
    #expect(pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.isEmpty == false)
}

@MainActor
@Test func imageHistoryItemWithMissingFileDoesNotClaimSuccess() {
    let pasteboard = NSPasteboard.withUniqueName()
    let item = ClipboardHistoryItem(
        type: ClipboardItemType.image.rawValue,
        content: "/tmp/missing-clipboard-image-\(UUID().uuidString).png",
        searchKeywords: "missing"
    )

    let didWrite = ClipboardManagerViewModel.write(item, to: pasteboard)

    #expect(!didWrite)
}

@MainActor
@Test func monitorPrefersFileURLsOverStringRepresentations() throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("clipboard-file-\(UUID().uuidString).txt")
    try "file contents".write(to: fileURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let pasteboard = NSPasteboard.withUniqueName()
    pasteboard.clearContents()
    pasteboard.writeObjects([fileURL as NSURL])
    pasteboard.setString(fileURL.path, forType: .string)

    let items = ClipboardMonitor.items(from: pasteboard, appName: "TestApp")

    #expect(items.count == 1)
    #expect(items.first?.type == .file)
    #expect(items.first?.content == fileURL.path)
}

@MainActor
@Test func monitorPrefersImageOverFallbackString() throws {
    let imageDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("clipboard-images-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: imageDirectory) }

    let pasteboard = NSPasteboard.withUniqueName()
    pasteboard.clearContents()
    pasteboard.writeObjects([makeTestImage()])
    pasteboard.setString("fallback text", forType: .string)

    let items = ClipboardMonitor.items(
        from: pasteboard,
        appName: "TestApp",
        imageDirectory: imageDirectory
    )

    #expect(items.count == 1)
    #expect(items.first?.type == .image)
    #expect(items.first?.content.hasPrefix(imageDirectory.path) == true)
}

@MainActor
@Test func monitorTreatsFileURLStringsAsFiles() throws {
    let firstURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("clipboard-url-\(UUID().uuidString).txt")
    let secondURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("clipboard-path-\(UUID().uuidString).txt")
    try "first".write(to: firstURL, atomically: true, encoding: .utf8)
    try "second".write(to: secondURL, atomically: true, encoding: .utf8)
    defer {
        try? FileManager.default.removeItem(at: firstURL)
        try? FileManager.default.removeItem(at: secondURL)
    }

    let pasteboard = NSPasteboard.withUniqueName()
    pasteboard.clearContents()
    pasteboard.setString("\(firstURL.absoluteString)\n\(secondURL.path)", forType: .string)

    let items = ClipboardMonitor.items(from: pasteboard, appName: "TestApp")

    #expect(items.map(\.type) == [.file, .file])
    #expect(items.map(\.content) == [firstURL.path, secondURL.path])
}

@MainActor
@Test func monitorTreatsUnescapedFileURLStringsAsFiles() throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("clipboard url \(UUID().uuidString).txt")
    try "file".write(to: fileURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let pasteboard = NSPasteboard.withUniqueName()
    pasteboard.clearContents()
    pasteboard.setString("file://\(fileURL.path)", forType: .string)

    let items = ClipboardMonitor.items(from: pasteboard, appName: "TestApp")

    #expect(items.map(\.type) == [.file])
    #expect(items.map(\.content) == [fileURL.path])
}

@MainActor
@Test func monitorKeepsMixedPathTextAsText() throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("clipboard-mixed-\(UUID().uuidString).txt")
    try "file".write(to: fileURL, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: fileURL) }

    let text = "\(fileURL.path)\nnot a file path"
    let pasteboard = NSPasteboard.withUniqueName()
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)

    let items = ClipboardMonitor.items(from: pasteboard, appName: "TestApp")

    #expect(items.count == 1)
    #expect(items.first?.type == .text)
    #expect(items.first?.content == text)
}

@Test func localStoreSavesAndReloadsSettings() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ClipboardManagerLocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = ClipboardManagerPluginLocalStore(settingsDirectory: directory)

    #expect(store.set(false, forKey: "ClipboardMonitoringEnabled") == true)
    #expect(store.set(1000, forKey: "ClipboardHistorySize") == true)

    let reloadedStore = ClipboardManagerPluginLocalStore(settingsDirectory: directory)
    #expect(reloadedStore.bool(forKey: "ClipboardMonitoringEnabled") == false)
    #expect(reloadedStore.integer(forKey: "ClipboardHistorySize") == 1000)
}

@Test func localStoreQuarantinesInvalidSettingsFileAndRecovers() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ClipboardManagerLocalStore-Invalid-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let settingsURL = directory.appendingPathComponent("settings.plist")
    let corruptURL = directory.appendingPathComponent("settings.corrupt.plist")
    let invalidData = Data("not a plist".utf8)
    try invalidData.write(to: settingsURL)

    let store = ClipboardManagerPluginLocalStore(settingsDirectory: directory)

    #expect(store.set(false, forKey: "ClipboardMonitoringEnabled") == true)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)
    #expect(store.bool(forKey: "ClipboardMonitoringEnabled") == false)

    let reloadedStore = ClipboardManagerPluginLocalStore(settingsDirectory: directory)
    #expect(reloadedStore.bool(forKey: "ClipboardMonitoringEnabled") == false)
}

@Test func localStoreReportsFailureWhenSettingsDirectoryIsBlocked() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("ClipboardManagerLocalStore-Blocked-\(UUID().uuidString)", isDirectory: true)
    let blockedDirectory = tempRoot.appendingPathComponent("settings", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let store = ClipboardManagerPluginLocalStore(settingsDirectory: blockedDirectory)

    #expect(store.set(false, forKey: "ClipboardMonitoringEnabled") == false)
    #expect(store.object(forKey: "ClipboardMonitoringEnabled") == nil)
}

@Test func historyStoreFallsBackWhenDatabaseDirectoryIsBlocked() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("clipboard-store-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let blockedDirectory = root.appendingPathComponent("ClipboardManager", isDirectory: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let container = ClipboardHistoryManager.makeContainer(databaseDirectory: root)
    let context = ModelContext(container)
    let item = ClipboardHistoryItem(
        type: ClipboardItemType.text.rawValue,
        content: "fallback item",
        searchKeywords: "fallback item"
    )

    context.insert(item)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<ClipboardHistoryItem>())
    #expect(fetched.count == 1)
    #expect(fetched.first?.content == "fallback item")
}

@Test func historyManagerReportsPersistenceResults() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("clipboard-history-manager-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let manager = ClipboardHistoryManager(databaseDirectory: root)
    let item = ClipboardHistoryItem(
        type: ClipboardItemType.text.rawValue,
        content: "persisted item",
        searchKeywords: "persisted item"
    )

    let added = await manager.add(item)
    let latest = await manager.getLatest(limit: 10)
    let storedId = try #require(latest.first?.id)
    let pinned = await manager.updatePinStatus(id: storedId, isPinned: true)
    let pinnedItems = await manager.getPinned()
    let deleted = await manager.delete(id: storedId)
    let remaining = await manager.getLatest(limit: 10)

    #expect(added)
    #expect(latest.count == 1)
    #expect(latest.first?.content == "persisted item")
    #expect(pinned)
    #expect(pinnedItems.map(\.id) == [storedId])
    #expect(deleted)
    #expect(remaining.isEmpty)
}

@Test func historyManagerClampsFetchLimitsBeforeQuerying() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("clipboard-history-limits-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let manager = ClipboardHistoryManager(databaseDirectory: root)
    for index in 0..<3 {
        let item = ClipboardHistoryItem(
            type: ClipboardItemType.text.rawValue,
            content: "item \(index)",
            searchKeywords: "item \(index)"
        )
        #expect(await manager.add(item))
    }

    let latest = await manager.getLatest(limit: -10)
    let all = await manager.getAll(limit: 0)
    let searched = await manager.search(keyword: "item", limit: Int.max)

    #expect(ClipboardHistoryManager.normalizedFetchLimit(-10) == 1)
    #expect(ClipboardHistoryManager.normalizedFetchLimit(0) == 1)
    #expect(ClipboardHistoryManager.normalizedFetchLimit(100) == 100)
    #expect(ClipboardHistoryManager.normalizedFetchLimit(Int.max) == ClipboardHistoryManager.maxFetchLimit)
    #expect(latest.count == 1)
    #expect(all.count == 1)
    #expect(searched.count == 3)
}

private func makeTestPNG() throws -> Data {
    let image = makeTestImage()
    let tiffData = try #require(image.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiffData))
    return try #require(bitmap.representation(using: .png, properties: [:]))
}

private func makeTestImage() -> NSImage {
    let image = NSImage(size: NSSize(width: 2, height: 2))
    image.lockFocus()
    NSColor.systemRed.setFill()
    NSRect(x: 0, y: 0, width: 2, height: 2).fill()
    image.unlockFocus()
    return image
}
