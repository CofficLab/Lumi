import AppKit
import SwiftData
import Testing
@testable import PluginClipboardManager

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
