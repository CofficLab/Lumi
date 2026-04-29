import AppKit
import Foundation
import LanguageServerProtocol
import UniformTypeIdentifiers

final class EditorDocumentController {
    private static let truncationFileSizeThreshold: Int64 = 2 * 1024 * 1024

    struct LoadedTextDocument {
        let content: String
        let fileSize: Int64
        let isTruncated: Bool
        let largeFileMode: LargeFileMode
        let fileExtension: String
        let fileName: String
    }

    struct LoadedBinaryDocument {
        let fileSize: Int64
        let largeFileMode: LargeFileMode
        let fileExtension: String
        let fileName: String
    }

    enum LoadedDocument {
        case text(LoadedTextDocument)
        case binary(LoadedBinaryDocument)
    }

    private(set) var buffer: EditorBuffer?
    private(set) var textStorage: NSTextStorage?
    private(set) var persistedTextSnapshot: String?

    var currentText: String? {
        buffer?.text ?? textStorage?.string
    }

    func clear() {
        buffer = nil
        textStorage = nil
        persistedTextSnapshot = nil
    }

    @discardableResult
    func load(text: String) -> EditorEditResult {
        let buffer = EditorBuffer(text: text)
        self.buffer = buffer
        syncTextStorage(from: buffer.text)
        return EditorEditResult(snapshot: buffer.snapshot(), selections: nil)
    }

    @discardableResult
    func replaceText(_ text: String) -> EditorEditResult {
        let result: EditorEditResult
        if let buffer {
            result = buffer.replaceText(text)
        } else {
            let newBuffer = EditorBuffer(text: text)
            buffer = newBuffer
            result = EditorEditResult(snapshot: newBuffer.snapshot(), selections: nil)
        }
        syncTextStorage(from: result.snapshot.text)
        return result
    }

    @discardableResult
    func apply(transaction: EditorTransaction) -> EditorEditResult? {
        guard let buffer else { return nil }
        let previousText = buffer.text
        guard let result = buffer.apply(transaction) else { return nil }
        guard result.snapshot.text != previousText else { return nil }
        syncTextStorage(from: result.snapshot.text)
        return result
    }

    @discardableResult
    func applyTextEdits(_ edits: [TextEdit]) -> EditorEditResult? {
        guard let text = currentText else { return nil }
        guard let transaction = TextEditTransactionBuilder.makeTransaction(edits: edits, in: text) else {
            return nil
        }
        return apply(transaction: transaction)
    }

    @discardableResult
    func applyTextStorageEdit(range: NSRange, text: String) -> EditorEditResult? {
        guard let buffer else { return nil }
        let previousText = buffer.text
        let transaction = EditorTransaction(
            replacements: [
                .init(
                    range: EditorRange(location: range.location, length: range.length),
                    text: text
                )
            ]
        )
        guard let result = buffer.apply(transaction), result.snapshot.text != previousText else {
            return nil
        }

        if let textStorage {
            if textStorage.string != result.snapshot.text {
                textStorage.mutableString.setString(result.snapshot.text)
            }
        } else {
            textStorage = NSTextStorage(string: result.snapshot.text)
        }
        return result
    }

    @discardableResult
    func syncBufferFromTextStorageIfNeeded() -> EditorEditResult? {
        guard let textStorage else { return nil }
        guard buffer?.text != textStorage.string else { return nil }
        return replaceText(textStorage.string)
    }

    func markPersistedText(_ text: String) {
        persistedTextSnapshot = text
    }

    func clearPersistedTextSnapshot() {
        persistedTextSnapshot = nil
    }

    func hasChangesComparedToPersistedSnapshot(_ text: String) -> Bool {
        guard let persistedTextSnapshot else { return false }
        return text != persistedTextSnapshot
    }

    func loadDocument(from url: URL, truncationReadBytes: Int, forceFullLoad: Bool = false) throws -> LoadedDocument {
        let fileSize = Int64((try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        let largeFileMode = LargeFileMode.mode(for: fileSize)
        let fileExtension = url.pathExtension.lowercased()
        let fileName = url.lastPathComponent

        guard try isLikelyTextFile(url: url) else {
            return .binary(
                .init(
                    fileSize: fileSize,
                    largeFileMode: largeFileMode,
                    fileExtension: fileExtension,
                    fileName: fileName
                )
            )
        }

        let shouldTruncate = !forceFullLoad && shouldUseTruncatedPreview(for: url, fileSize: fileSize)
        let content: String
        if shouldTruncate {
            content = try readTruncatedContent(from: url, maxBytes: truncationReadBytes)
        } else {
            var detectedEncoding = String.Encoding.utf8
            content = try String(contentsOf: url, usedEncoding: &detectedEncoding)
        }

        return .text(
            .init(
                content: content,
                fileSize: fileSize,
                isTruncated: shouldTruncate,
                largeFileMode: largeFileMode,
                fileExtension: fileExtension,
                fileName: fileName
            )
        )
    }

    private func syncTextStorage(from text: String) {
        if let textStorage {
            if textStorage.string != text {
                textStorage.mutableString.setString(text)
            }
        } else {
            textStorage = NSTextStorage(string: text)
        }
    }

    private func shouldUseTruncatedPreview(for url: URL, fileSize: Int64) -> Bool {
        let ext = url.pathExtension.lowercased()
        let alwaysFullLoadExtensions: Set<String> = ["md", "markdown", "txt"]
        if alwaysFullLoadExtensions.contains(ext) {
            return false
        }
        return fileSize > Self.truncationFileSizeThreshold
    }

    private func readTruncatedContent(from url: URL, maxBytes: Int) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        let data = try handle.read(upToCount: maxBytes) ?? Data()
        let preview: String
        if let string = String(data: data, encoding: .utf8) {
            preview = string
        } else {
            preview = String(decoding: data, as: UTF8.self)
        }
        let suffix = "\n\n… " + String(localized: "File too large. Preview is truncated.", table: "LumiEditor")
        return preview + suffix
    }

    private func isLikelyTextFile(url: URL) throws -> Bool {
        let ext = url.pathExtension.lowercased()
        let obviousTextExts: Set<String> = [
            "swift", "m", "mm", "h", "hpp", "c", "cc", "cpp", "rs", "go", "py", "rb", "php", "java", "kt", "kts", "js", "ts", "tsx", "jsx", "json", "md", "txt", "yml", "yaml", "toml", "ini", "conf", "sh", "zsh", "bash", "fish", "html", "css", "scss", "sass", "less", "xml", "plist", "sql", "graphql", "proto", "env", "gitignore", "editorconfig", "xcodeproj", "pbxproj",
        ]

        if obviousTextExts.contains(ext) {
            return true
        }

        if let type = UTType(filenameExtension: ext) {
            if type.conforms(to: .text) || type.conforms(to: .sourceCode) || type.conforms(to: .xml) || type.conforms(to: .json) || type.conforms(to: .propertyList) {
                return true
            }
        }

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 1024) ?? Data()
        if data.isEmpty { return true }
        if data.contains(0) { return false }
        return true
    }
}
