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
}
