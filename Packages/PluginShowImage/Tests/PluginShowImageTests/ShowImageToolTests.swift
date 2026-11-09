import Foundation
import KitAgentTool
import Testing
@testable import PluginShowImage


@Suite(.serialized)
struct ShowImageToolTests {
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
    }

    @Test func imageSourcePreservesLocalPathWhitespace() throws {
        // 首尾空白可能属于真实文件名，本地路径必须逐字节保留。
        #expect(try ShowImageTool.normalizedSource(from: "/tmp/lumi-preview.png ") == .local("/tmp/lumi-preview.png "))
        #expect(try ShowImageTool.normalizedSource(from: " /tmp/lumi-preview.png") == .local(" /tmp/lumi-preview.png"))
        #expect(try ShowImageTool.normalizedSource(from: "/tmp/plain.png") == .local("/tmp/plain.png"))
    }

    @Test func imageSourceRejectsMissingAndUnsupportedSchemes() {
        expectSourceError(" \n ", .missingSource)
        expectSourceError("data:image/png;base64,AAAA", .unsupportedScheme("data"))
        expectSourceError("ftp://example.com/image.png", .unsupportedScheme("ftp"))
    }

    /// 回归 #1066：有 http(s) scheme 但没有 authority/host 的地址不是可加载的图片 URL。
    @Test func imageSourceRejectsRemoteURLWithoutHost() {
        expectSourceError("https:image.png", .missingRemoteHost("https:image.png"))
        expectSourceError("http:///image.png", .missingRemoteHost("http:///image.png"))
        expectSourceError("https://user@:443/image.png", .missingRemoteHost("https://user@:443/image.png"))
    }

    @Test @MainActor func rejectsRemoteURLWithoutHostWithoutPublishing() async throws {
        let tool = ShowImageTool(network: nil)
        let state = ShowImageState.shared
        state.clear()

        await #expect(throws: ShowImageTool.ShowImageError.missingRemoteHost("https:image.png")) {
            _ = try await tool.executeResult(arguments: ["source": ToolArgument("https:image.png")])
        }
        #expect(state.displayItem == nil)
    }

    /// 回归 #1094：file URL 的 authority 不能被丢弃，否则会读成本机同路径文件。
    @Test func imageSourceRejectsNonLocalFileURLHost() throws {
        expectSourceError(
            "file://server/tmp/existing.png",
            .nonLocalFileHost("file://server/tmp/existing.png")
        )
        expectSourceError(
            "file://files.corp.internal/Users/me/photo.png",
            .nonLocalFileHost("file://files.corp.internal/Users/me/photo.png")
        )
        // 空 authority 与 localhost 才指向本机。
        #expect(try ShowImageTool.normalizedSource(from: "file:///tmp/existing.png") == .local("/tmp/existing.png"))
        #expect(try ShowImageTool.normalizedSource(from: "file://localhost/tmp/existing.png") == .local("/tmp/existing.png"))
    }

    @Test @MainActor func rejectsNonLocalFileURLWithoutPublishing() async throws {
        let tool = ShowImageTool(network: nil)
        let state = ShowImageState.shared
        state.clear()

        // 本机同路径文件存在且是有效图片；旧实现会静默发布它并报告成功。
        let imageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("valid-image-\(UUID()).png")
        try testPNGData().write(to: imageURL)
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let remoteFileURL = "file://server" + imageURL.path
        await #expect(throws: ShowImageTool.ShowImageError.nonLocalFileHost(remoteFileURL)) {
            _ = try await tool.executeResult(arguments: ["source": ToolArgument(remoteFileURL)])
        }
        #expect(state.displayItem == nil)
    }

    @Test func maximumWidthUsesDefaultAndClampsEveryInputForm() {
        #expect(ShowImageTool.normalizedMaxWidth(nil) == 400)
        #expect(ShowImageTool.normalizedMaxWidth("bad") == 400)
        // 字符串会先 trim 再解析，`" 500 "` 是合法请求。
        #expect(ShowImageTool.normalizedMaxWidth(" 500 ") == 500)
        #expect(ShowImageTool.normalizedMaxWidth(99) == 100)
        #expect(ShowImageTool.normalizedMaxWidth(300.8) == 300)
        #expect(ShowImageTool.normalizedMaxWidth("650") == 650)
        #expect(ShowImageTool.normalizedMaxWidth(801) == 800)
        // `ToolArgumentNumber` 的约定：无法安全表示的数值（越界 / 非有限）
        // 视为非法输入退回默认值，而不是当作「超大但合法」钳到上界。
        #expect(ShowImageTool.normalizedMaxWidth(1e100) == 400)
        #expect(ShowImageTool.normalizedMaxWidth(Double.infinity) == 400)
        #expect(ShowImageTool.normalizedMaxWidth(-Double.infinity) == 400)
        #expect(ShowImageTool.normalizedMaxWidth(Double.nan) == 400)
    }

    @Test @MainActor func executeValidatesLocalFilesAndPublishesNormalizedDisplayState() async throws {
        let tool = ShowImageTool(network: nil)
        let state = ShowImageState.shared
        state.clear()

        await #expect(throws: ShowImageTool.ShowImageError.missingSource) {
            try await tool.execute(arguments: [:])
        }
        await #expect(throws: ShowImageTool.ShowImageError.missingSource) {
            try await tool.execute(arguments: ["source": ToolArgument(" \n ")])
        }

        await #expect(throws: ShowImageTool.ShowImageError.unsupportedScheme("data")) {
            try await tool.execute(arguments: ["source": ToolArgument("data:image/png;base64,AAAA")])
        }

        let missingPath = FileManager.default.temporaryDirectory.appendingPathComponent("missing-image-\(UUID()).png")
        await #expect(throws: ShowImageTool.ShowImageError.fileNotFound(missingPath.path)) {
            try await tool.execute(arguments: ["source": ToolArgument(missingPath.path)])
        }

        let textURL = FileManager.default.temporaryDirectory.appendingPathComponent("not-an-image-\(UUID()).txt")
        try Data("text".utf8).write(to: textURL)
        defer { try? FileManager.default.removeItem(at: textURL) }
        await #expect(throws: ShowImageTool.ShowImageError.unsupportedFormat(
            ext: "txt",
            supported: ShowImageTool.supportedImageExtensions
        )) {
            try await tool.execute(arguments: ["source": ToolArgument(textURL.path)])
        }
        #expect(state.displayItem == nil)

        let imageURL = FileManager.default.temporaryDirectory.appendingPathComponent("valid-image-\(UUID()).png")
        try testPNGData().write(to: imageURL)
        defer { try? FileManager.default.removeItem(at: imageURL) }
        let result = try await tool.execute(arguments: [
            "source": ToolArgument(imageURL.path),
            "title": ToolArgument("  Diagram  "),
            "caption": ToolArgument(" \n "),
            "maxWidth": ToolArgument(Double.infinity),
        ])

        #expect(result == "Image displayed successfully. Source: \(imageURL.path)")
        #expect(state.displayItem?.source == .local(imageURL.path))
        #expect(state.displayItem?.title == "Diagram")
        #expect(state.displayItem?.caption == nil)
        #expect(state.displayItem?.maxWidth == 400)

        // 文件名末尾的空格是合法字符，不能被裁剪成另一个路径。
        let spacedImageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("valid-image-\(UUID()).png ")
        try testPNGData().write(to: spacedImageURL)
        defer { try? FileManager.default.removeItem(at: spacedImageURL) }
        let spacedResult = try await tool.execute(arguments: [
            "source": ToolArgument(spacedImageURL.path),
        ])
        #expect(spacedResult.contains("File not found") == false)
        #expect(state.displayItem?.source == .local(spacedImageURL.path))

        state.clear()
        #expect(state.displayItem == nil)
    }

    @Test @MainActor func validationFailuresThrowThroughExecuteResult() async throws {
        let tool = ShowImageTool(network: nil)
        let state = ShowImageState.shared
        state.clear()

        // 回归 #765：校验失败曾经只返回 "Error: ..." 字符串，默认 executeResult
        // 仍产出 isError == false，工具 Job 以 completed 结束。
        await #expect(throws: ShowImageTool.ShowImageError.missingSource) {
            _ = try await tool.executeResult(arguments: [:])
        }

        let missingPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-image-\(UUID()).png")
        await #expect(throws: ShowImageTool.ShowImageError.fileNotFound(missingPath.path)) {
            _ = try await tool.executeResult(arguments: ["source": ToolArgument(missingPath.path)])
        }

        let imageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("valid-image-\(UUID()).png")
        try testPNGData().write(to: imageURL)
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let result = try await tool.executeResult(arguments: ["source": ToolArgument(imageURL.path)])
        #expect(result.isError == false)
        #expect(result.content.contains("Image displayed successfully"))

        state.clear()
    }

    @Test @MainActor func rejectsDirectoryUnreadableAndUndecodableSources() async throws {
        let tool = ShowImageTool(network: nil)
        let state = ShowImageState.shared
        state.clear()

        // 回归 #766：目录曾经只因为路径存在 + 扩展名白名单就通过校验，
        // 并被发布成有效的显示项。
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("folder-\(UUID()).png")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        await #expect(throws: ShowImageTool.ShowImageError.notAFile(directoryURL.path)) {
            _ = try await tool.executeResult(arguments: ["source": ToolArgument(directoryURL.path)])
        }
        // 共享状态可能被并行用例更新，这里只断言「非法源没有被发布」。
        #expect(state.displayItem?.source != .local(directoryURL.path))

        // 内容不是图片的「伪造 .png」同样必须拒绝。
        let fakeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("fake-\(UUID()).png")
        try Data("this is definitely not an image".utf8).write(to: fakeURL)
        defer { try? FileManager.default.removeItem(at: fakeURL) }
        await #expect(throws: ShowImageTool.ShowImageError.undecodableImage(fakeURL.path)) {
            _ = try await tool.executeResult(arguments: ["source": ToolArgument(fakeURL.path)])
        }
        #expect(state.displayItem?.source != .local(fakeURL.path))

        // 只有文件头、没有像素数据的截断图片也不能算成功。
        let truncatedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("truncated-\(UUID()).png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: truncatedURL)
        defer { try? FileManager.default.removeItem(at: truncatedURL) }
        await #expect(throws: ShowImageTool.ShowImageError.undecodableImage(truncatedURL.path)) {
            _ = try await tool.executeResult(arguments: ["source": ToolArgument(truncatedURL.path)])
        }
        #expect(state.displayItem?.source != .local(truncatedURL.path))

        // 无可读权限的文件必须报「无法读取」，而不是通过校验。
        let lockedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("locked-\(UUID()).png")
        try testPNGData().write(to: lockedURL)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: lockedURL.path)
            try? FileManager.default.removeItem(at: lockedURL)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: lockedURL.path)
        await #expect(throws: ShowImageTool.ShowImageError.unreadableFile(lockedURL.path)) {
            _ = try await tool.executeResult(arguments: ["source": ToolArgument(lockedURL.path)])
        }
        #expect(state.displayItem?.source != .local(lockedURL.path))
    }

}

// 1×1 红色 PNG：校验现在要求内容真的可解码，占位字节不再够用。
private func testPNGData() -> Data {
    Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
}

private func expectSourceError(
    _ source: String,
    _ expected: ShowImageTool.ShowImageError,
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) {
    do {
        _ = try ShowImageTool.normalizedSource(from: source)
        Issue.record("Expected source normalization to fail", sourceLocation: sourceLocation)
    } catch let error as ShowImageTool.ShowImageError {
        #expect(error == expected, sourceLocation: sourceLocation)
    } catch {
        Issue.record("Unexpected error: \(error)", sourceLocation: sourceLocation)
    }
}
