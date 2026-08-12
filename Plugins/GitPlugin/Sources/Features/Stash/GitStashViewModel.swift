import Foundation
import SwiftUI
import LibGit2Swift

/// 暂存面板的视图模型。
///
/// 仅持有 UI 状态与「轻量异步刷新」能力；具体操作委托给
/// `GitStashService`。
@MainActor
public final class GitStashViewModel: ObservableObject {
    @Published public private(set) var entries: [GitStashEntry] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastError: String?
    @Published public var pushMessage: String = ""

    public init() {}

    /// 当前关联的工程路径。
    public var projectPath: String = ""

    public var hasStash: Bool { !entries.isEmpty }

    public func refresh() async {
        let path = projectPath
        guard !path.isEmpty else {
            entries = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        let snapshot = await Task.detached(priority: .userInitiated) {
            GitStashService.list(at: path)
        }.value
        entries = snapshot
        lastError = nil
    }

    public func push() async {
        let path = projectPath
        guard !path.isEmpty else { return }
        do {
            _ = try GitStashService.push(message: pushMessage.nilIfBlank, at: path)
            pushMessage = ""
            await refresh()
        } catch {
            lastError = GitStashError.pushFailed("\(error)").errorDescription
        }
    }

    public func pop(index: Int) async {
        do {
            try GitStashService.pop(index: index, at: projectPath)
            await refresh()
        } catch {
            lastError = GitStashError.popFailed("\(error)").errorDescription
        }
    }

    public func apply(index: Int) async {
        do {
            try GitStashService.apply(index: index, at: projectPath)
            await refresh()
        } catch {
            lastError = GitStashError.applyFailed("\(error)").errorDescription
        }
    }

    public func drop(index: Int) async {
        do {
            try GitStashService.drop(index: index, at: projectPath)
            await refresh()
        } catch {
            lastError = GitStashError.dropFailed("\(error)").errorDescription
        }
    }

    public func clearAll() async {
        do {
            try GitStashService.clear(at: projectPath)
            await refresh()
        } catch {
            lastError = GitStashError.clearFailed("\(error)").errorDescription
        }
    }
}

private extension String {
    /// `nil` if string is empty or only contains whitespace; otherwise `String`.
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
