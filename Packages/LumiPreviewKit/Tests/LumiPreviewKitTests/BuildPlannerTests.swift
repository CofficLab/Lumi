import Foundation
import Testing
@testable import LumiPreviewKit

@Suite("BuildPlanner")
struct BuildPlannerTests {

    // MARK: - 基本检测

    @Test("无项目上下文的文件 → 返回 nil")
    func planUnknownPath() {
        let planner = BuildPlanner()
        let result = planner.plan(for: URL(fileURLWithPath: "/tmp/Nonexistent.swift"))
        #expect(result == nil)
    }

    @Test("SPM Package 中的文件 → 返回 .spm 策略")
    func planSPMFile() {
        let planner = BuildPlanner()
        // 使用 LumiPreviewKit 自身的源文件来测试
        let fileURL = URL(fileURLWithPath: "/Users/colorfy/Code/CofficLab/Lumi/Packages/LumiPreviewKit/Sources/LumiPreviewKit/Scanner/PreviewScanner.swift")
        let result = planner.plan(for: fileURL)

        guard case let .spm(packageDirectory, targetName) = result else {
            Issue.record("Expected .spm strategy, got \(String(describing: result))")
            return
        }
        #expect(targetName == "LumiPreviewKit")
        #expect(packageDirectory.lastPathComponent == "LumiPreviewKit")
    }

    @Test("Lumi 自身的 LumiUI Package 文件能被正确识别")
    func planLumiUIPackage() {
        let planner = BuildPlanner()
        // 直接构造 LumiUI Package 中的一个已知文件路径
        let fileURL = URL(fileURLWithPath: "/Users/colorfy/Code/CofficLab/Lumi/Packages/LumiUI/Sources/LumiUI/LumiUI.swift")
        let result = planner.plan(for: fileURL)

        guard case let .spm(packageDirectory, targetName) = result else {
            Issue.record("Expected .spm strategy for LumiUI file, got \(String(describing: result))")
            return
        }
        #expect(packageDirectory.lastPathComponent == "LumiUI")
        #expect(targetName == "LumiUI")
    }

    @Test("LumiPreviewHostApp 可执行 target 能被正确识别")
    func planHostAppTarget() {
        let planner = BuildPlanner()
        let fileURL = URL(fileURLWithPath: "/Users/colorfy/Code/CofficLab/Lumi/Packages/LumiPreviewKit/Sources/LumiPreviewHostApp/main.swift")
        let result = planner.plan(for: fileURL)

        guard case let .spm(_, targetName) = result else {
            Issue.record("Expected .spm strategy for HostApp file, got \(String(describing: result))")
            return
        }
        #expect(targetName == "LumiPreviewHostApp")
    }

    @Test("Xcode 项目中的文件 → 返回 .xcode 策略")
    func planXcodeProjectFile() throws {
        let project = try makeTemporaryXcodeContainer(
            extensionName: "xcodeproj",
            schemeName: "SharedAppScheme"
        )
        defer { try? FileManager.default.removeItem(at: project.rootDirectory) }

        let result = BuildPlanner().plan(for: project.sourceFile)

        guard case let .xcode(projectURL, scheme, configuration) = result else {
            Issue.record("Expected .xcode strategy, got \(String(describing: result))")
            return
        }

        #expect(projectURL.lastPathComponent == "TemporaryApp.xcodeproj")
        #expect(scheme == "SharedAppScheme")
        #expect(configuration == "Debug")
    }

    @Test("同一目录有 workspace 和 project 时优先使用 workspace")
    func planXcodeWorkspaceBeforeProject() throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-XcodePlanner-\(UUID().uuidString)", isDirectory: true)
        let sourceDirectory = rootDirectory.appendingPathComponent("Sources", isDirectory: true)
        let sourceFile = sourceDirectory.appendingPathComponent("ContentView.swift")
        let workspaceURL = rootDirectory.appendingPathComponent("TemporaryApp.xcworkspace", isDirectory: true)
        let projectURL = rootDirectory.appendingPathComponent("TemporaryApp.xcodeproj", isDirectory: true)

        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try "import SwiftUI\n".write(to: sourceFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let result = BuildPlanner().plan(for: sourceFile)

        guard case let .xcode(containerURL, scheme, _) = result else {
            Issue.record("Expected .xcode strategy, got \(String(describing: result))")
            return
        }

        #expect(containerURL.pathExtension == "xcworkspace")
        #expect(scheme == "TemporaryApp")
    }

    @Test("Package.swift 优先于上层 Xcode 项目")
    func planPackageBeforeAncestorXcodeProject() throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-MixedPlanner-\(UUID().uuidString)", isDirectory: true)
        let projectURL = rootDirectory.appendingPathComponent("TemporaryApp.xcodeproj", isDirectory: true)
        let packageDirectory = rootDirectory.appendingPathComponent("NestedPackage", isDirectory: true)
        let sourceDirectory = packageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("NestedTarget", isDirectory: true)
        let sourceFile = sourceDirectory.appendingPathComponent("View.swift")

        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "NestedPackage",
            targets: [.target(name: "NestedTarget")]
        )
        """.write(to: packageDirectory.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        try "import SwiftUI\n".write(to: sourceFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: rootDirectory) }

        let result = BuildPlanner().plan(for: sourceFile)

        guard case let .spm(packageURL, targetName) = result else {
            Issue.record("Expected .spm strategy, got \(String(describing: result))")
            return
        }

        #expect(packageURL.lastPathComponent == "NestedPackage")
        #expect(targetName == "NestedTarget")
    }

    private func makeTemporaryXcodeContainer(
        extensionName: String,
        schemeName: String
    ) throws -> (rootDirectory: URL, sourceFile: URL) {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LumiPreviewKit-XcodePlanner-\(UUID().uuidString)", isDirectory: true)
        let sourceDirectory = rootDirectory.appendingPathComponent("Sources", isDirectory: true)
        let sourceFile = sourceDirectory.appendingPathComponent("ContentView.swift")
        let projectURL = rootDirectory.appendingPathComponent("TemporaryApp.\(extensionName)", isDirectory: true)
        let schemesDirectory = projectURL
            .appendingPathComponent("xcshareddata", isDirectory: true)
            .appendingPathComponent("xcschemes", isDirectory: true)

        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: schemesDirectory, withIntermediateDirectories: true)
        try "import SwiftUI\n".write(to: sourceFile, atomically: true, encoding: .utf8)
        try "<Scheme />\n".write(
            to: schemesDirectory.appendingPathComponent("\(schemeName).xcscheme"),
            atomically: true,
            encoding: .utf8
        )

        return (rootDirectory, sourceFile)
    }
}
