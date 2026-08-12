import Foundation
import SwiftUI
import LibGit2Swift

/// Submodule 面板视图模型。
@MainActor
public final class GitSubmoduleViewModel: ObservableObject {
    @Published public private(set) var submodules: [GitSubmoduleInfo] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastError: String?
    @Published public private(set) var lastInfo: String?

    public init() {}
    public var projectPath: String = ""

    public func refresh() async {
        let path = projectPath
        guard !path.isEmpty else { submodules = []; return }
        isLoading = true
        defer { isLoading = false }
        let snapshot = await Task.detached(priority: .userInitiated) {
            GitSubmoduleService.list(at: path)
        }.value
        submodules = snapshot
    }

    public func initializeAll() async {
        do {
            try GitSubmoduleService.initialize(at: projectPath, recursive: true)
            lastInfo = "Submodules initialized."
            lastError = nil
            await refresh()
        } catch {
            lastError = "Initialize failed: \(error.localizedDescription)"
        }
    }

    public func updateAll(initialize: Bool = false) async {
        do {
            try GitSubmoduleService.update(at: projectPath, initialize: initialize, recursive: true)
            lastInfo = "Submodules updated."
            lastError = nil
            await refresh()
        } catch {
            lastError = "Update failed: \(error.localizedDescription)"
        }
    }

    public func updateOne(_ path: String) async {
        do {
            try GitSubmoduleService.update(paths: [path], at: projectPath, initialize: false, recursive: true)
            lastInfo = "Updated \(path)"
            lastError = nil
            await refresh()
        } catch {
            lastError = "Update failed for \(path): \(error.localizedDescription)"
        }
    }
}
