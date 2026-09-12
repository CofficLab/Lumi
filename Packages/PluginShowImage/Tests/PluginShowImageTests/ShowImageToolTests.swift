import Foundation
import KitAgentTool
import Testing
@testable import PluginShowImage

@Test func imageSourcesNormalizeLocalAndRemoteLocations() throws {
    #expect(ShowImageSource.local("/tmp/image.png").stringValue == "/tmp/image.png")
    #expect(!ShowImageSource.local("/tmp/image.png").isRemote)

    let remote = try ShowImageTool.normalizedSource(from: "  HTTPS://example.com/image.png  ")
    #expect(remote.isRemote)
    if case .remote(let url) = remote {
        #expect(URL(string: url)?.scheme?.lowercased() == "https")
    } else {
        Issue.record("Expected an HTTPS image source")
    }

    let fileURL = URL(fileURLWithPath: "/tmp/image with spaces.png")
    #expect(try ShowImageTool.normalizedSource(from: fileURL.absoluteString) == .local(fileURL.path))
    #expect(try ShowImageTool.normalizedSource(from: " /tmp/plain.png ") == .local("/tmp/plain.png"))
}

@Test func imageSourceRejectsMissingAndUnsupportedSchemes() {
    expectSourceError(" \n ", .missingSource)
    expectSourceError("data:image/png;base64,AAAA", .unsupportedScheme("data"))
    expectSourceError("ftp://example.com/image.png", .unsupportedScheme("ftp"))
}

@Test func maximumWidthUsesDefaultAndClampsEveryInputForm() {
    #expect(ShowImageTool.normalizedMaxWidth(nil) == 400)
    #expect(ShowImageTool.normalizedMaxWidth("bad") == 400)
    #expect(ShowImageTool.normalizedMaxWidth(" 500 ") == 400)
    #expect(ShowImageTool.normalizedMaxWidth(99) == 100)
    #expect(ShowImageTool.normalizedMaxWidth(300.8) == 300)
    #expect(ShowImageTool.normalizedMaxWidth("650") == 650)
    #expect(ShowImageTool.normalizedMaxWidth(801) == 800)
    #expect(ShowImageTool.normalizedMaxWidth(1e100) == 800)
    #expect(ShowImageTool.normalizedMaxWidth(Double.infinity) == 800)
    #expect(ShowImageTool.normalizedMaxWidth(-Double.infinity) == 100)
    #expect(ShowImageTool.normalizedMaxWidth(Double.nan) == 400)
}

@Test @MainActor func executeValidatesLocalFilesAndPublishesNormalizedDisplayState() async throws {
    let tool = ShowImageTool(network: nil)
    let state = ShowImageState.shared
    state.clear()

    let missingSource = try await tool.execute(arguments: [:])
    #expect(missingSource.contains("Missing required 'source'"))
    let emptySource = try await tool.execute(arguments: ["source": ToolArgument(" \n ")])
    #expect(emptySource.contains("Missing required 'source'"))

    let unsupportedScheme = try await tool.execute(arguments: ["source": ToolArgument("data:image/png;base64,AAAA")])
    #expect(unsupportedScheme.contains("Unsupported image URL scheme 'data'"))

    let missingPath = FileManager.default.temporaryDirectory.appendingPathComponent("missing-image-\(UUID()).png")
    let missingFile = try await tool.execute(arguments: ["source": ToolArgument(missingPath.path)])
    #expect(missingFile.contains("File not found"))

    let textURL = FileManager.default.temporaryDirectory.appendingPathComponent("not-an-image-\(UUID()).txt")
    try Data("text".utf8).write(to: textURL)
    defer { try? FileManager.default.removeItem(at: textURL) }
    let unsupportedFormat = try await tool.execute(arguments: ["source": ToolArgument(textURL.path)])
    #expect(unsupportedFormat.contains("Unsupported image format 'txt'"))
    #expect(state.displayItem == nil)

    let imageURL = FileManager.default.temporaryDirectory.appendingPathComponent("valid-image-\(UUID()).png")
    try Data([0x89, 0x50, 0x4E, 0x47]).write(to: imageURL)
    defer { try? FileManager.default.removeItem(at: imageURL) }
    let result = try await tool.execute(arguments: [
        "source": ToolArgument("  \(imageURL.path)  "),
        "title": ToolArgument("  Diagram  "),
        "caption": ToolArgument(" \n "),
        "maxWidth": ToolArgument(Double.infinity),
    ])

    #expect(result == "Image displayed successfully. Source: \(imageURL.path)")
    #expect(state.displayItem?.source == .local(imageURL.path))
    #expect(state.displayItem?.title == "Diagram")
    #expect(state.displayItem?.caption == nil)
    #expect(state.displayItem?.maxWidth == 800)
    state.clear()
    #expect(state.displayItem == nil)
}

private func expectSourceError(
    _ source: String,
    _ expected: ShowImageTool.SourceError,
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) {
    do {
        _ = try ShowImageTool.normalizedSource(from: source)
        Issue.record("Expected source normalization to fail", sourceLocation: sourceLocation)
    } catch let error as ShowImageTool.SourceError {
        #expect(error == expected, sourceLocation: sourceLocation)
    } catch {
        Issue.record("Unexpected error: \(error)", sourceLocation: sourceLocation)
    }
}
