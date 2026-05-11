import Foundation
import Testing
@testable import LumiPreviewKit

@Suite("SPMCompiler")
struct SPMCompilerTests {

    @Test("编译存在的 SPM executable target → 成功返回产物路径")
    func buildExistingExecutableTarget() async throws {
        let packageDirectory = try makeTemporaryPackage(
            targetName: "HelloTool",
            sourceFileName: "main.swift",
            source: """
            @main
            struct HelloTool {
                static func main() {
                    print("hello")
                }
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: packageDirectory) }

        let productURL = try await SPMCompiler().build(
            packageDirectory: packageDirectory,
            targetName: "HelloTool"
        )

        #expect(FileManager.default.fileExists(atPath: productURL.path))
        #expect(productURL.path.contains("HelloTool"))
    }

    @Test("编译不存在的 target → 抛出 compilationFailed")
    func buildMissingTargetThrowsCompilationFailed() async throws {
        let packageDirectory = try makeTemporaryPackage(
            targetName: "HelloTool",
            sourceFileName: "main.swift",
            source: """
            @main
            struct HelloTool {
                static func main() {}
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: packageDirectory) }

        do {
            _ = try await SPMCompiler().build(
                packageDirectory: packageDirectory,
                targetName: "MissingTool"
            )
            Issue.record("Expected compilationFailed")
        } catch PreviewError.compilationFailed(let message) {
            #expect(message.localizedCaseInsensitiveContains("error"))
            #expect(message.localizedCaseInsensitiveContains("MissingTool"))
        } catch {
            Issue.record("Expected compilationFailed, got \(error)")
        }
    }

    @Test("编译有语法错误的代码 → 错误信息包含文件名和行号")
    func buildSyntaxErrorIncludesFileAndLine() async throws {
        let packageDirectory = try makeTemporaryPackage(
            targetName: "BrokenTool",
            sourceFileName: "Broken.swift",
            source: """
            @main
            struct BrokenTool {
                static func main() {
                    let value =
                    print(value)
                }
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: packageDirectory) }

        do {
            _ = try await SPMCompiler().build(
                packageDirectory: packageDirectory,
                targetName: "BrokenTool"
            )
            Issue.record("Expected compilationFailed")
        } catch PreviewError.compilationFailed(let message) {
            #expect(message.contains("Broken.swift"))
            #expect(message.contains(":5:"))
        } catch {
            Issue.record("Expected compilationFailed, got \(error)")
        }
    }

    private func makeTemporaryPackage(
        targetName: String,
        sourceFileName: String,
        source: String
    ) throws -> URL {
        let packageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKitTests-\(UUID().uuidString)", isDirectory: true)
        let sourceDirectory = packageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(targetName, isDirectory: true)

        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "\(targetName)Package",
            platforms: [.macOS(.v14)],
            targets: [
                .executableTarget(name: "\(targetName)")
            ]
        )
        """.write(
            to: packageDirectory.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )
        try source.write(
            to: sourceDirectory.appendingPathComponent(sourceFileName),
            atomically: true,
            encoding: .utf8
        )

        return packageDirectory
    }
}
