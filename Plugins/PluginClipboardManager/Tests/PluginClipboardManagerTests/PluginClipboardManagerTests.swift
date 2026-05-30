import AppKit
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

private func makeTestPNG() throws -> Data {
    let image = NSImage(size: NSSize(width: 2, height: 2))
    image.lockFocus()
    NSColor.systemRed.setFill()
    NSRect(x: 0, y: 0, width: 2, height: 2).fill()
    image.unlockFocus()

    let tiffData = try #require(image.tiffRepresentation)
    let bitmap = try #require(NSBitmapImageRep(data: tiffData))
    return try #require(bitmap.representation(using: .png, properties: [:]))
}
