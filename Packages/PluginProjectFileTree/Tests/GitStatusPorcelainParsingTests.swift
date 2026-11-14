import Foundation
import Testing

@testable import PluginProjectFileTree

/// 回归 #1106 / #442：porcelain 以 `-z` NUL 分隔输出，路径原样保留。
/// 普通文件名里的 ` -> ` 不属于重命名；rename/copy 的旧路径是独立的 NUL 字段。
struct GitStatusPorcelainParsingTests {

    @Test("普通文件名中的箭头不会被当作重命名")
    func arrowInRegularFileNameIsPreserved() {
        let porcelain = "?? Sources/a -> b.swift\0 M Sources/c -> d.swift\0"

        let unstaged = GitStatusProvider.unstagedFiles(from: porcelain)

        #expect(unstaged.map(\.file) == ["Sources/a -> b.swift", "Sources/c -> d.swift"])
        #expect(unstaged.map(\.changeType) == ["?", "M"])
    }

    @Test("暂存区重命名取新路径字段")
    func stagedRenameUsesDestinationPath() {
        let staged = GitStatusProvider.stagedFiles(from: "R  new.swift\0old.swift\0")

        #expect(staged.map(\.file) == ["new.swift"])
        #expect(staged.map(\.changeType) == ["R"])
    }

    @Test("工作区重命名同样取新路径字段")
    func worktreeRenameUsesDestinationPath() {
        let unstaged = GitStatusProvider.unstagedFiles(from: " R new.swift\0old.swift\0")

        #expect(unstaged.map(\.file) == ["new.swift"])
        #expect(unstaged.map(\.changeType) == ["R"])
    }

    @Test("add/add 与 delete/delete 冲突按 conflicted 处理")
    func addAddAndDeleteDeleteAreConflicted() {
        let porcelain = "AA Conflict.swift\0DD Removed.swift\0UU Both.swift\0"

        let staged = GitStatusProvider.stagedFiles(from: porcelain)

        #expect(staged.map(\.file) == ["Conflict.swift", "Removed.swift", "Both.swift"])
        #expect(staged.map(\.changeType) == ["C", "C", "C"])
        #expect(GitStatusProvider.parseStatus("C") == .conflicted)
        #expect(GitStatusProvider.unstagedFiles(from: porcelain).isEmpty)
    }

    @Test("全部未合并状态码都被识别，普通状态不会被误判")
    func unmergedCodesAreRecognized() {
        for code in ["DD", "AU", "UD", "UA", "DU", "AA", "UU"] {
            let characters = Array(code)
            #expect(
                GitStatusProvider.isUnmerged(x: characters[0], y: characters[1]),
                "\(code) 应识别为未合并"
            )
        }

        for code in [" M", "M ", "A ", " D", "??", "R ", " C"] {
            let characters = Array(code)
            #expect(
                !GitStatusProvider.isUnmerged(x: characters[0], y: characters[1]),
                "\(code) 不应识别为未合并"
            )
        }
    }

    @Test("中文文件名经 NUL 分隔解析后原样保留，不得丢失或转义")
    func nulSeparatedChinesePathIsPreserved() {
        let porcelain = " M 测试.txt\0?? 新建文件夹/文档.swift\0"

        let unstaged = GitStatusProvider.unstagedFiles(from: porcelain)

        #expect(unstaged.map(\.file) == ["测试.txt", "新建文件夹/文档.swift"])
        #expect(unstaged.map(\.changeType) == ["M", "?"])
    }

    @Test("rename 的旧路径字段被消费，不会被当成独立条目")
    func renameOldPathFieldIsConsumed() {
        let porcelain = "R  new.swift\0old.swift\0 M other.swift\0"

        let staged = GitStatusProvider.stagedFiles(from: porcelain)
        let unstaged = GitStatusProvider.unstagedFiles(from: porcelain)

        #expect(staged.map(\.file) == ["new.swift"])
        #expect(unstaged.map(\.file) == ["other.swift"])
    }
}