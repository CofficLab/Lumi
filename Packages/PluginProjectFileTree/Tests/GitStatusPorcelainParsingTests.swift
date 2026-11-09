import Foundation
import Testing

@testable import PluginProjectFileTree

/// 回归 #1106：porcelain 的 `old -> new` 分隔只属于 rename/copy 条目。
/// 普通文件名本身可以包含 ` -> `，无条件截断会让快照键失真。
struct GitStatusPorcelainParsingTests {

    @Test("普通文件名中的箭头不会被当作重命名")
    func arrowInRegularFileNameIsPreserved() {
        let porcelain = """
        ?? Sources/a -> b.swift
         M Sources/c -> d.swift
        """

        let unstaged = GitStatusProvider.unstagedFiles(from: porcelain)

        #expect(unstaged.map(\.file) == ["Sources/a -> b.swift", "Sources/c -> d.swift"])
        #expect(unstaged.map(\.changeType) == ["?", "M"])
    }

    @Test("暂存区重命名仍取箭头后的新路径")
    func stagedRenameUsesDestinationPath() {
        let staged = GitStatusProvider.stagedFiles(from: "R  old.swift -> new.swift")

        #expect(staged.map(\.file) == ["new.swift"])
        #expect(staged.map(\.changeType) == ["R"])
    }

    @Test("工作区重命名同样取箭头后的新路径")
    func worktreeRenameUsesDestinationPath() {
        let unstaged = GitStatusProvider.unstagedFiles(from: " R old.swift -> new.swift")

        #expect(unstaged.map(\.file) == ["new.swift"])
        #expect(unstaged.map(\.changeType) == ["R"])
    }

    @Test("add/add 与 delete/delete 冲突按 conflicted 处理")
    func addAddAndDeleteDeleteAreConflicted() {
        let porcelain = """
        AA Conflict.swift
        DD Removed.swift
        UU Both.swift
        """

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
}
