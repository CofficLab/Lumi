import Testing
import Foundation
import LanguageServerProtocol
@testable import EditorKernel

@Suite("WorkspaceEditFileOperations")
struct WorkspaceEditFileOperationsTests {
    @Test("fileURL supports file URI and absolute path")
    func fileURLParsing() {
        let fileURI = "file:///tmp/test.swift"
        #expect(WorkspaceEditFileOperations.fileURL(from: fileURI)?.path == "/tmp/test.swift")

        let absolutePath = "/tmp/test-2.swift"
        #expect(WorkspaceEditFileOperations.fileURL(from: absolutePath)?.path == absolutePath)
    }

    @Test("create and delete file operations succeed")
    func createDeleteOperations() {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("editor-kernel-core-tests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = root.appendingPathComponent("a/b/file.swift")
        defer { try? FileManager.default.removeItem(at: root) }

        let create = CreateFile(kind: "create", uri: fileURL.absoluteString, options: nil)
        #expect(WorkspaceEditFileOperations.applyCreateFile(create) == true)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let delete = DeleteFile(
            kind: "delete",
            uri: fileURL.absoluteString,
            options: .init(recursive: false, ignoreIfNotExists: false)
        )
        #expect(WorkspaceEditFileOperations.applyDeleteFile(delete) == true)
        #expect(FileManager.default.fileExists(atPath: fileURL.path) == false)
    }
}
