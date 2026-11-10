import Foundation
import Testing
@testable import EditorService

/// 回归 #734：打开非 UTF-8 文档时必须保留检测到的编码，保存才能按原编码写回。
@Suite("EditorDocumentEncoding")
struct EditorDocumentEncodingTests {

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("editor-doc-encoding-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("打开 UTF-16 文本时记录检测到的编码，按该编码写回字节不变")
    func loadTextDocumentCapturesDetectedEncoding() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = root.appendingPathComponent("sample.txt")
        try "hello".write(to: url, atomically: true, encoding: .utf16)
        let originalBytes = try Data(contentsOf: url)

        let loaded = try EditorDocumentController().loadDocument(
            from: url,
            truncationReadBytes: 4096
        )
        guard case let .text(document) = loaded else {
            Issue.record("txt 文件应走文本加载路径")
            return
        }

        #expect(document.content == "hello")
        #expect(document.encoding != .utf8, "UTF-16 文档不应被记录成 UTF-8")

        // 以记录的编码写回，应与原文件完全一致（含 BOM 与字节序）。
        let rewritten = root.appendingPathComponent("rewritten.txt")
        try document.content.write(to: rewritten, atomically: true, encoding: document.encoding)
        #expect(try Data(contentsOf: rewritten) == originalBytes)
    }

    @Test("UTF-8 文本记录的编码仍为 UTF-8")
    func loadUTF8DocumentKeepsUTF8() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let url = root.appendingPathComponent("plain.txt")
        try "hello".write(to: url, atomically: true, encoding: .utf8)

        let loaded = try EditorDocumentController().loadDocument(
            from: url,
            truncationReadBytes: 4096
        )
        guard case let .text(document) = loaded else {
            Issue.record("txt 文件应走文本加载路径")
            return
        }

        #expect(document.encoding == .utf8)
    }
}
