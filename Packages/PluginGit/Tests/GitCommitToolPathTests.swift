import Testing
import Foundation
@testable import GitPlugin

/// #176 回归：绝对路径 → 仓库相对路径的转换必须使用仓库边界判断
/// （等于根目录，或位于 `root + "/"` 之下），不得用裸 `hasPrefix`。
///
/// 旧测试用一个私有 `resolveFiles` 复制了被测逻辑（并未触达真实代码），且
/// `prefixSimilarButNotChildShouldRemainUnchanged` 只断言 `count == 1`，无法阻止 bug。
/// 这里改为直接验证真实的边界原语 `GitService.relativePath(_:fromRepositoryRoot:)`
/// ——`GitService.commit` 修复后复用它——并用真实临时目录确保 realpath 规范化稳定。
///
/// 端到端的真实提交回归见 `GitCommitRealCommitTests`（本包已能在 swift test 中
/// 真实运行 LibGit2，旧文件「沙箱无法测试 commit」的说明已过时）。
@Suite("GitCommitTool 路径边界测试")
struct GitCommitToolPathTests {

    private func withTempLayout(_ body: (URL) throws -> Void) throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitPluginTests/path176-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        try body(parent)
    }

    private func makeDir(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func touch(_ url: URL) throws {
        try makeDir(url.deletingLastPathComponent())
        try "x".write(to: url, atomically: true, encoding: .utf8)
    }

    @Test("仓库内绝对路径转换为相对路径")
    func absolutePathInsideRepoBecomesRelative() throws {
        try withTempLayout { parent in
            let repo = parent.appendingPathComponent("App")
            try makeDir(repo)
            let file = repo.appendingPathComponent("Sources/Foo.swift")
            try touch(file)
            #expect(GitService.relativePath(file.path, fromRepositoryRoot: repo.path) == "Sources/Foo.swift")
        }
    }

    @Test("嵌套目录的绝对路径正确转换")
    func nestedDirectoryAbsolutePathBecomesRelative() throws {
        try withTempLayout { parent in
            let repo = parent.appendingPathComponent("App")
            try makeDir(repo)
            let file = repo.appendingPathComponent("Packages/LumiUI/Sources/Charts/AppBarChart.swift")
            try touch(file)
            #expect(GitService.relativePath(file.path, fromRepositoryRoot: repo.path) == "Packages/LumiUI/Sources/Charts/AppBarChart.swift")
        }
    }

    @Test("仓库根路径本身转换为空字符串")
    func repoRootItselfBecomesEmpty() throws {
        try withTempLayout { parent in
            let repo = parent.appendingPathComponent("App")
            try makeDir(repo)
            #expect(GitService.relativePath(repo.path, fromRepositoryRoot: repo.path) == "")
        }
    }

    @Test("同名前缀的兄弟目录文件必须判为仓库外，不得改写成内部路径")
    func siblingSamePrefixIsRejected() throws {
        try withTempLayout { parent in
            let repo = parent.appendingPathComponent("App")
            try makeDir(repo)
            let siblingFile = parent.appendingPathComponent("App-old/file.txt")
            try touch(siblingFile)
            // 裸 hasPrefix 会把它误映射成 "-old/file.txt"；正确边界判断必须返回 nil。
            #expect(GitService.relativePath(siblingFile.path, fromRepositoryRoot: repo.path) == nil)
        }
    }

    @Test("前缀相似但非子路径的文件必须拒绝，不得错误匹配")
    func siblingPrefixSubstringIsRejected() throws {
        try withTempLayout { parent in
            let repo = parent.appendingPathComponent("My")
            try makeDir(repo)
            let file = parent.appendingPathComponent("MyProject/F.swift")
            try touch(file)
            #expect(GitService.relativePath(file.path, fromRepositoryRoot: repo.path) == nil)
        }
    }

    @Test("仓库外路径返回 nil")
    func externalPathIsRejected() throws {
        try withTempLayout { parent in
            let repo = parent.appendingPathComponent("App")
            try makeDir(repo)
            let external = parent.appendingPathComponent("Other/Dir/File.swift")
            try touch(external)
            #expect(GitService.relativePath(external.path, fromRepositoryRoot: repo.path) == nil)
        }
    }
}
