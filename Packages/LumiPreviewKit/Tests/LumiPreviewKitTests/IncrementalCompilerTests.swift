import Foundation
import Testing
@testable import LumiPreviewKit

@Suite("IncrementalCompiler")
struct IncrementalCompilerTests {

    @Test("单文件编译 → 输出 object file")
    func compileSingleFileReturnsObjectFile() async throws {
        let fixture = try makeTemporarySwiftFile(
            source: """
            public func previewValue() -> String {
                "hello"
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let objectURL = fixture.directory.appendingPathComponent("PreviewSnippet.o")
        let command = "/usr/bin/env swiftc -c \(shellQuoted(fixture.file.path)) -o \(shellQuoted(objectURL.path))"

        let compiledObjectURL = try await IncrementalCompiler().compile(
            fileURL: fixture.file,
            compileCommand: command
        )

        #expect(compiledObjectURL == objectURL)
        #expect(FileManager.default.fileExists(atPath: compiledObjectURL.path))
    }

    @Test("链接 object file → 输出 dylib")
    func linkObjectFileReturnsDylib() async throws {
        let fixture = try makeTemporarySwiftFile(
            source: """
            public func previewValue() -> String {
                "hello"
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let objectURL = fixture.directory.appendingPathComponent("PreviewSnippet.o")
        let command = "/usr/bin/env swiftc -c \(shellQuoted(fixture.file.path)) -o \(shellQuoted(objectURL.path))"
        let compiler = IncrementalCompiler()
        let compiledObjectURL = try await compiler.compile(
            fileURL: fixture.file,
            compileCommand: command
        )

        let dylibURL = try await compiler.link(objectFileURL: compiledObjectURL)

        #expect(dylibURL.pathExtension == "dylib")
        #expect(FileManager.default.fileExists(atPath: dylibURL.path))
    }

    @Test("codesign dylib → 签名验证通过")
    func codesignDylibPassesVerification() async throws {
        let fixture = try makeTemporarySwiftFile(
            source: """
            public func previewValue() -> String {
                "hello"
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let objectURL = fixture.directory.appendingPathComponent("PreviewSnippet.o")
        let command = "/usr/bin/env swiftc -c \(shellQuoted(fixture.file.path)) -o \(shellQuoted(objectURL.path))"
        let compiler = IncrementalCompiler()
        let compiledObjectURL = try await compiler.compile(
            fileURL: fixture.file,
            compileCommand: command
        )
        let dylibURL = try await compiler.link(objectFileURL: compiledObjectURL)

        try await compiler.codesign(dylibURL: dylibURL)

        #expect(try verifyCodeSignature(at: dylibURL))
    }

    @Test("单文件编译失败 → 返回编译错误")
    func compileSyntaxErrorThrowsCompilationFailed() async throws {
        let fixture = try makeTemporarySwiftFile(
            source: """
            public func broken() -> String {
                let value =
                return value
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let command = "/usr/bin/env swiftc -c \(shellQuoted(fixture.file.path))"

        do {
            _ = try await IncrementalCompiler().compile(
                fileURL: fixture.file,
                compileCommand: command
            )
            Issue.record("Expected compilationFailed")
        } catch PreviewError.compilationFailed(let message) {
            #expect(message.contains("PreviewSnippet.swift"))
            #expect(message.localizedCaseInsensitiveContains("error"))
        } catch {
            Issue.record("Expected compilationFailed, got \(error)")
        }
    }

    private func makeTemporarySwiftFile(source: String) throws -> (directory: URL, file: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-IncrementalCompiler-\(UUID().uuidString)", isDirectory: true)
        let file = directory.appendingPathComponent("PreviewSnippet.swift")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try source.write(to: file, atomically: true, encoding: .utf8)

        return (directory, file)
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func verifyCodeSignature(at url: URL) throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", url.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()

        return process.terminationStatus == 0
    }
}
