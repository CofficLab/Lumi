import Foundation
import LibGit2Swift
import SwiftUI

/// Git 分支缓存
///
/// 为每个项目路径缓存当前分支名，避免频繁的磁盘 I/O。
/// 支持批量加载（视图出现时一次性刷新所有可见项目）和单条刷新（项目切换时）。
///
/// 刷新时机：
/// - 视图首次出现
/// - 项目路径变化
/// - 从其他应用切回（`applicationDidBecomeActive`）
@MainActor
final class GitBranchCache: ObservableObject {
    /// 项目路径 → 分支名（nil 表示非 Git 仓库或未加载）
    @Published private(set) var branches: [String: String] = [:]

    /// 标记正在加载的路径，避免重复请求
    private var loadingPaths: Set<String> = []

    // MARK: - Public API

    /// 获取指定项目的分支名（同步，可能为 nil）
    func branch(for path: String) -> String? {
        branches[path]
    }

    /// 批量刷新多个项目路径的分支信息
    func refresh(paths: [String]) {
        let pathsToLoad = paths.filter { branches[$0] == nil && !loadingPaths.contains($0) }
        guard !pathsToLoad.isEmpty else { return }

        for path in pathsToLoad {
            loadingPaths.insert(path)
        }

        Task.detached { [pathsToLoad] in
            var results: [String: String] = [:]
            for path in pathsToLoad {
                if let branch = try? LibGit2.getCurrentBranch(at: path) {
                    results[path] = branch
                }
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                for (path, branch) in results {
                    self.branches[path] = branch
                }
                for path in pathsToLoad {
                    self.loadingPaths.remove(path)
                }
                // 对于未获取到分支的路径，标记为空字符串以避免重复加载
                for path in pathsToLoad where results[path] == nil && self.branches[path] == nil {
                    self.branches[path] = ""
                }
            }
        }
    }

    /// 刷新单个项目路径的分支信息（强制刷新，即使已缓存）
    func refresh(path: String) {
        guard !loadingPaths.contains(path) else { return }

        loadingPaths.insert(path)

        Task.detached { [path] in
            let branch = (try? LibGit2.getCurrentBranch(at: path)) ?? ""
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.branches[path] = branch
                self.loadingPaths.remove(path)
            }
        }
    }

    /// 清除指定路径的缓存（项目切换后调用）
    func invalidate(path: String) {
        branches.removeValue(forKey: path)
    }

    /// 清除所有缓存
    func invalidateAll() {
        branches.removeAll()
    }
}
