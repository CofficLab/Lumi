#if canImport(XCTest)
import Foundation
import XCTest
@testable import EditorFileTreePlugin

/// 文件树 Git 状态标记的纯逻辑单元测试。
///
/// 覆盖 `GitStatusProvider` 的 `parseStatus` 映射、`computeDirectoryAggregate` 目录聚合、
/// `GitStatus.highest` 优先级合并，以及 staged + unstaged 同文件的合并语义。
/// 这些测试不依赖 LibGit2，因此可在无网络环境下快速验证核心逻辑。
final class EditorFileTreeGitStatusTests: XCTestCase {

    // MARK: - parseStatus

    func testParseStatusMapsKnownChangeTypes() {
        XCTAssertEqual(GitStatusProvider.parseStatus("M"), .modified)
        XCTAssertEqual(GitStatusProvider.parseStatus("A"), .added)
        XCTAssertEqual(GitStatusProvider.parseStatus("D"), .deleted)
        XCTAssertEqual(GitStatusProvider.parseStatus("R"), .renamed)
        XCTAssertEqual(GitStatusProvider.parseStatus("?"), .untracked)
        XCTAssertEqual(GitStatusProvider.parseStatus("C"), .conflicted)
    }

    func testParseStatusFallsBackToModifiedForUnknownType() {
        // 未知 changeType 一律视为修改（有 diff 即修改），与 git 行为一致
        XCTAssertEqual(GitStatusProvider.parseStatus("XYZ"), .modified)
        XCTAssertEqual(GitStatusProvider.parseStatus(""), .modified)
    }

    // MARK: - GitStatus.highest 优先级

    func testHighestPicksByPriority() {
        // conflicted (6) 高于 deleted (5) 高于 modified (2)
        XCTAssertEqual(GitStatus.highest(.conflicted, .modified), .conflicted)
        XCTAssertEqual(GitStatus.highest(.modified, .deleted), .deleted)
        // added 与 untracked 同为 3，左结合（>=）
        XCTAssertEqual(GitStatus.highest(.added, .untracked), .added)
        XCTAssertEqual(GitStatus.highest(.untracked, .added), .untracked)
        // staged (1) 最低
        XCTAssertEqual(GitStatus.highest(.staged, .modified), .modified)
    }

    /// staged + unstaged 同一文件：取优先级更高的状态。
    /// 这是「git add 后文件又被改动」场景——既要体现 staged，又要体现更高优先级的 unstaged 变更。
    func testStagedAndUnstagedSameFileMergesToHigherPriority() {
        let staged = GitStatusEntry(relativePath: "src/a.swift", status: .added, isStaged: true)
        let unstaged = GitStatusEntry(relativePath: "src/a.swift", status: .modified, isStaged: false)
        // added (3) 高于 modified (2)
        let merged = GitStatus.highest(staged.status, unstaged.status)
        XCTAssertEqual(merged, .added)
    }

    // MARK: - computeDirectoryAggregate

    func testDirectoryAggregatePropagatesStatusUpward() {
        // src/foo/bar.swift (M) → src/foo/ (M), src/ (M)
        let entries = [
            GitStatusEntry(relativePath: "src/foo/bar.swift", status: .modified),
        ]
        let aggregate = GitStatusProvider.computeDirectoryAggregate(entries: entries)

        XCTAssertEqual(aggregate["src"], .modified)
        XCTAssertEqual(aggregate["src/foo"], .modified)
        // 文件本身不应作为目录 key 出现
        XCTAssertNil(aggregate["src/foo/bar.swift"])
    }

    func testDirectoryAggregatePicksHighestAmongChildren() {
        // 同一目录下一个 modified、一个 deleted：目录应聚合为 deleted（优先级更高）
        let entries = [
            GitStatusEntry(relativePath: "src/a.swift", status: .modified),
            GitStatusEntry(relativePath: "src/b.swift", status: .deleted),
        ]
        let aggregate = GitStatusProvider.computeDirectoryAggregate(entries: entries)

        XCTAssertEqual(aggregate["src"], .deleted)
    }

    func testDirectoryAggregateForNestedDirectories() {
        // 深层目录的变更应逐级向上传播；根级目录应反映后代中的最高优先级
        let entries = [
            GitStatusEntry(relativePath: "app/main.swift", status: .added),
            GitStatusEntry(relativePath: "lib/util/parser.swift", status: .conflicted),
        ]
        let aggregate = GitStatusProvider.computeDirectoryAggregate(entries: entries)

        XCTAssertEqual(aggregate["app"], .added)
        XCTAssertEqual(aggregate["lib"], .conflicted)
        XCTAssertEqual(aggregate["lib/util"], .conflicted)
    }

    func testDirectoryAggregateIgnoresRootLevelFiles() {
        // 仓库根目录下的文件没有父目录组件，不应产生任何目录聚合条目
        let entries = [
            GitStatusEntry(relativePath: "README.md", status: .modified),
            GitStatusEntry(relativePath: "Package.swift", status: .added),
        ]
        let aggregate = GitStatusProvider.computeDirectoryAggregate(entries: entries)
        XCTAssertTrue(aggregate.isEmpty)
    }

    // MARK: - GitStatusSnapshot 查询

    func testSnapshotStatusForPathAndAggregate() {
        let snapshot = GitStatusSnapshot(
            entriesByRelativePath: [
                "src/a.swift": GitStatusEntry(relativePath: "src/a.swift", status: .modified),
            ],
            directoryAggregateByRelativePath: ["src": .modified],
            repoRootPath: "/repo",
            capturedAt: Date()
        )

        XCTAssertEqual(snapshot.statusForPath("src/a.swift"), .modified)
        XCTAssertNil(snapshot.statusForPath("src/missing.swift"))
        XCTAssertEqual(snapshot.aggregateStatusForDirectory("src"), .modified)
        XCTAssertNil(snapshot.aggregateStatusForDirectory("other"))
    }

    func testEmptySnapshotIsConsideredEmpty() {
        XCTAssertTrue(GitStatusSnapshot.empty.isEmpty)
        XCTAssertNil(GitStatusSnapshot.empty.statusForPath("any.swift"))
    }
}
#endif
