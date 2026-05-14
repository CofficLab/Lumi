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

        let productURL = try await LumiPreviewPackage.SPMCompiler().build(
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
            _ = try await LumiPreviewPackage.SPMCompiler().build(
                packageDirectory: packageDirectory,
                targetName: "MissingTool"
            )
            Issue.record("Expected compilationFailed")
        } catch LumiPreviewPackage.PreviewError.compilationFailed(let message) {
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
            _ = try await LumiPreviewPackage.SPMCompiler().build(
                packageDirectory: packageDirectory,
                targetName: "BrokenTool"
            )
            Issue.record("Expected compilationFailed")
        } catch LumiPreviewPackage.PreviewError.compilationFailed(let message) {
            #expect(message.contains("Broken.swift"))
            #expect(message.contains(":5:"))
        } catch {
            Issue.record("Expected compilationFailed, got \(error)")
        }
    }

    @Test("previewCompilerArguments 包含模块、include、链接输入和 linkedLibrary")
    func previewCompilerArgumentsIncludeBuildProductsAndLinkedLibraries() throws {
        let packageDirectory = try makeTemporaryPackage(
            targetName: "PreviewTarget",
            sourceFileName: "main.swift",
            source: """
            @main
            struct PreviewTarget {
                static func main() {}
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: packageDirectory) }

        let debugDirectory = packageDirectory
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent("debug", isDirectory: true)
        let modulesDirectory = debugDirectory.appendingPathComponent("Modules", isDirectory: true)
        let includeDirectory = debugDirectory.appendingPathComponent("include", isDirectory: true)
        try FileManager.default.createDirectory(at: modulesDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: includeDirectory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: debugDirectory.appendingPathComponent("Helper.o").path, contents: Data())
        FileManager.default.createFile(atPath: debugDirectory.appendingPathComponent("PreviewTarget.o").path, contents: Data())
        FileManager.default.createFile(atPath: debugDirectory.appendingPathComponent("libSupport.a").path, contents: Data())
        FileManager.default.createFile(atPath: debugDirectory.appendingPathComponent("libPreviewTarget.a").path, contents: Data())

        try """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "PreviewTargetPackage",
            targets: [
                .executableTarget(
                    name: "PreviewTarget",
                    linkerSettings: [
                        .linkedLibrary("sqlite3"),
                        .linkedLibrary("UIKit", .when(platforms: [.iOS])),
                        .linkedLibrary("AppKitSupport", .when(platforms: [.macOS]))
                    ]
                )
            ]
        )
        """.write(
            to: packageDirectory.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        let arguments = LumiPreviewPackage.SPMCompiler().previewCompilerArguments(
            packageDirectory: packageDirectory,
            targetName: "PreviewTarget"
        )

        #expect(arguments.contains(debugDirectory.path))
        #expect(arguments.contains(modulesDirectory.path))
        #expect(arguments.contains(includeDirectory.path))
        let normalizedArguments = arguments.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        #expect(normalizedArguments.contains(debugDirectory.appendingPathComponent("Helper.o").standardizedFileURL.path))
        #expect(normalizedArguments.contains(debugDirectory.appendingPathComponent("libSupport.a").standardizedFileURL.path))
        #expect(!normalizedArguments.contains(debugDirectory.appendingPathComponent("PreviewTarget.o").standardizedFileURL.path))
        #expect(!normalizedArguments.contains(debugDirectory.appendingPathComponent("libPreviewTarget.a").standardizedFileURL.path))
        #expect(arguments.contains("-lsqlite3"))
        #expect(arguments.contains("-lAppKitSupport"))
        #expect(!arguments.contains("-lUIKit"))
    }

    @Test("previewCompilerArguments 读取 checkout package 的 linkedLibrary")
    func previewCompilerArgumentsIncludeCheckoutLinkedLibraries() throws {
        let packageDirectory = try makeTemporaryPackage(
            targetName: "PreviewTarget",
            sourceFileName: "main.swift",
            source: """
            @main
            struct PreviewTarget {
                static func main() {}
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: packageDirectory) }

        let checkoutDirectory = packageDirectory
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent("checkouts", isDirectory: true)
            .appendingPathComponent("NativeDependency", isDirectory: true)
        try FileManager.default.createDirectory(at: checkoutDirectory, withIntermediateDirectories: true)
        try """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "NativeDependency",
            targets: [
                .target(
                    name: "NativeDependency",
                    linkerSettings: [.linkedLibrary("z")]
                )
            ]
        )
        """.write(to: checkoutDirectory.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        let arguments = LumiPreviewPackage.SPMCompiler().previewCompilerArguments(packageDirectory: packageDirectory)

        #expect(arguments.contains("-lz"))
    }

    @Test("previewCompilerArguments 排除测试 target 的对象文件")
    func previewCompilerArgumentsExcludeTestTargetObjects() throws {
        let packageDirectory = try makeTemporaryPackage(
            targetName: "PreviewTarget",
            sourceFileName: "main.swift",
            source: """
            @main
            struct PreviewTarget {
                static func main() {}
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: packageDirectory) }

        let debugDirectory = packageDirectory
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent("debug", isDirectory: true)
        let mainObject = debugDirectory.appendingPathComponent("Helper.o")
        let testBuildDirectory = debugDirectory.appendingPathComponent("LumiUITests.build", isDirectory: true)
        let testObject = testBuildDirectory.appendingPathComponent("AppButtonTests.swift.o")

        try FileManager.default.createDirectory(at: testBuildDirectory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: mainObject.path, contents: Data())
        FileManager.default.createFile(atPath: testObject.path, contents: Data())

        let arguments = LumiPreviewPackage.SPMCompiler().previewCompilerArguments(
            packageDirectory: packageDirectory,
            targetName: "PreviewTarget"
        )
        let normalizedArguments = arguments.map { URL(fileURLWithPath: $0).standardizedFileURL.path }

        #expect(normalizedArguments.contains(mainObject.standardizedFileURL.path))
        #expect(!normalizedArguments.contains(testObject.standardizedFileURL.path))
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
