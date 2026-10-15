import Foundation
import SwiftUI

/// Conflict Resolver 视图模型。
@MainActor
public final class GitConflictViewModel: ObservableObject {
    @Published public private(set) var conflicts: [GitConflictService.Conflict] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastError: String?
    @Published public private(set) var lastInfo: String?

    public init() {}
    public var projectPath: String = ""

    public var hasConflicts: Bool { !conflicts.isEmpty }

    public func refresh() async {
        let path = projectPath
        guard !path.isEmpty else { conflicts = []; return }
        isLoading = true
        defer { isLoading = false }
        conflicts = await GitConflictService.listConflicts(at: path)
    }

    public func resolve(_ conflict: GitConflictService.Conflict, with side: GitConflictService.Conflict.Resolution) async {
        do {
            switch side {
            case .ours:
                try await GitConflictService.resolveWithOurs(conflict.path, at: projectPath)
            case .theirs:
                try await GitConflictService.resolveWithTheirs(conflict.path, at: projectPath)
            case .manual:
                try await GitConflictService.markResolved(conflict.path, at: projectPath)
            }
            lastInfo = "Resolved: \(conflict.path)"
            lastError = nil
            await refresh()
        } catch {
            lastError = "Resolve failed: \(error.localizedDescription)"
        }
    }

    public func abort() async {
        do {
            try await GitConflictService.abortMerge(at: projectPath)
            lastInfo = "Merge aborted."
            lastError = nil
            await refresh()
        } catch {
            lastError = "Abort failed: \(error.localizedDescription)"
        }
    }
}
