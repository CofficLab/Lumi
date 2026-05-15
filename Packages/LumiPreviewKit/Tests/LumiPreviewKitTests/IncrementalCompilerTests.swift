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

        let compiledObjectURL = try await LumiPreviewFacade.IncrementalCompiler().compile(
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
        let compiler = LumiPreviewFacade.IncrementalCompiler()
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
        let compiler = LumiPreviewFacade.IncrementalCompiler()
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
            _ = try await LumiPreviewFacade.IncrementalCompiler().compile(
                fileURL: fixture.file,
                compileCommand: command
            )
            Issue.record("Expected compilationFailed")
        } catch LumiPreviewFacade.PreviewError.compilationFailed(let message) {
            #expect(message.contains("PreviewSnippet.swift"))
            #expect(message.localizedCaseInsensitiveContains("error"))
        } catch {
            Issue.record("Expected compilationFailed, got \(error)")
        }
    }

    @Test("library 编译支持额外模块与链接参数")
    func compileLibraryUsesCompilerArguments() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-IncrementalCompilerModule-\(UUID().uuidString)", isDirectory: true)
        let moduleSource = directory.appendingPathComponent("PreviewDependency.swift")
        let moduleURL = directory.appendingPathComponent("PreviewDependency.swiftmodule")
        let moduleObjectURL = directory.appendingPathComponent("PreviewDependency.o")
        let previewSource = directory.appendingPathComponent("PreviewEntry.swift")
        let dylibURL = directory.appendingPathComponent("PreviewEntry.dylib")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try """
        public enum PreviewDependencyMarker {
            public static func value() -> Int {
                42
            }
        }
        """.write(to: moduleSource, atomically: true, encoding: .utf8)
        try """
        import PreviewDependency

        public func previewValue() -> Int {
            PreviewDependencyMarker.value()
        }
        """.write(to: previewSource, atomically: true, encoding: .utf8)

        try run(
            "/usr/bin/env swiftc -parse-as-library -emit-module -emit-object -module-name PreviewDependency " +
                "\(shellQuoted(moduleSource.path)) " +
                "-emit-module-path \(shellQuoted(moduleURL.path)) " +
                "-o \(shellQuoted(moduleObjectURL.path))"
        )

        let compiledDylibURL = try await LumiPreviewFacade.IncrementalCompiler().compileLibrary(
            sourceURLs: [previewSource],
            dylibURL: dylibURL,
            compilerArguments: ["-I", directory.path, moduleObjectURL.path]
        )

        #expect(compiledDylibURL == dylibURL)
        #expect(FileManager.default.fileExists(atPath: dylibURL.path))
    }

    @Test("library 编译支持指定唯一 module name")
    func compileLibraryUsesProvidedModuleName() async throws {
        let fixture = try makeTemporarySwiftFile(
            source: """
            public func previewValue() -> Int {
                42
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: fixture.directory) }

        let dylibURL = fixture.directory.appendingPathComponent("PreviewEntry.dylib")
        let compiledDylibURL = try await LumiPreviewFacade.IncrementalCompiler().compileLibrary(
            sourceURLs: [fixture.file],
            dylibURL: dylibURL,
            compilerArguments: ["-module-name", "OldPreviewEntry"],
            moduleName: "UniquePreviewEntry"
        )

        #expect(compiledDylibURL == dylibURL)
        #expect(FileManager.default.fileExists(atPath: dylibURL.path))
    }

    private func makeTemporarySwiftFile(source: String) throws -> (directory: URL, file: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-LumiPreviewFacade.IncrementalCompiler-\(UUID().uuidString)", isDirectory: true)
        let file = directory.appendingPathComponent("PreviewSnippet.swift")

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try source.write(to: file, atomically: true, encoding: .utf8)

        return (directory, file)
    }

    private func shellQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func run(_ command: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
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
