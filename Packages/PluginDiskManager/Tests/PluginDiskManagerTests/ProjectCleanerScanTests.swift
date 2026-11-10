import Foundation
import Testing
@testable import PluginDiskManager

/// 回归 #661：根目录本身是可清理项目时，扫描不能就此停下，
/// monorepo 的子包依赖仍需被发现。
@Test func scanDirectoryFindsNestedProjectsUnderCleanableRoot() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("Monorepo-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let app = root.appendingPathComponent("packages/app", isDirectory: true)
    try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)

    try writePackage(withNodeModulesOfSize: 1024, at: root)
    try writePackage(withNodeModulesOfSize: 512, at: app)

    let projects = await ProjectCleanerService.scanDirectory(root.path, depth: 0, maxDepth: 4)
    // 目录遍历会把 /var 解析成 /private/var，比较前统一解析符号链接。
    let paths = Set(projects.map { URL(fileURLWithPath: $0.path).resolvingSymlinksInPath().path })

    #expect(paths.contains(URL(fileURLWithPath: root.path).resolvingSymlinksInPath().path))
    #expect(paths.contains(URL(fileURLWithPath: app.path).resolvingSymlinksInPath().path))
}

/// 可清理产物目录内部不应当再被当作项目扫描。
@Test func scanDirectoryDoesNotEnterCleanableDirectories() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("NestedModules-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let nestedPackage = root
        .appendingPathComponent("node_modules/left-pad/packages/inner", isDirectory: true)
    try FileManager.default.createDirectory(at: nestedPackage, withIntermediateDirectories: true)
    try writePackage(withNodeModulesOfSize: 256, at: nestedPackage)

    let projects = await ProjectCleanerService.scanDirectory(root.path, depth: 0, maxDepth: 4)

    #expect(projects.isEmpty)
}

private func writePackage(withNodeModulesOfSize size: Int, at directory: URL) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("{}".utf8).write(to: directory.appendingPathComponent("package.json"))

    let dependency = directory.appendingPathComponent("node_modules/dep", isDirectory: true)
    try fileManager.createDirectory(at: dependency, withIntermediateDirectories: true)
    try Data(repeating: 0, count: size).write(to: dependency.appendingPathComponent("index.js"))
}
