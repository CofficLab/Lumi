import Foundation
import SwiftUI

/// LFS 面板视图模型。
@MainActor
public final class GitLFSViewModel: ObservableObject {
    @Published public private(set) var isEnabled: Bool = false
    @Published public private(set) var trackedFiles: [LFSFile] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var lastError: String?
    @Published public private(set) var lastInfo: String?
    @Published public var newPattern: String = ""

    public init() {}
    public var projectPath: String = ""

    public func refresh() async {
        let path = projectPath
        guard !path.isEmpty else { isEnabled = false; trackedFiles = []; return }
        isLoading = true
        defer { isLoading = false }
        let enabled = await GitLFSService.isEnabled(at: path)
        let files = enabled
            ? await GitLFSService.listTracked(at: path)
            : []
        isEnabled = enabled
        trackedFiles = files
        if !enabled { lastInfo = nil }
    }

    public func install() async {
        do {
            _ = try await GitLFSService.install(at: projectPath)
            lastInfo = "LFS hooks installed."
            lastError = nil
            await refresh()
        } catch {
            lastError = "Install failed: \(error.localizedDescription)"
        }
    }

    public func fetch() async {
        do {
            _ = try await GitLFSService.fetch(at: projectPath)
            lastInfo = "LFS objects fetched."
            lastError = nil
        } catch {
            lastError = "Fetch failed: \(error.localizedDescription)"
        }
    }

    public func prune() async {
        do {
            _ = try await GitLFSService.prune(at: projectPath)
            lastInfo = "LFS cache pruned."
            lastError = nil
        } catch {
            lastError = "Prune failed: \(error.localizedDescription)"
        }
    }

    public func addPattern() async {
        let pattern = newPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pattern.isEmpty else { return }
        do {
            _ = try await GitLFSService.track(pattern, at: projectPath)
            newPattern = ""
            lastInfo = "Pattern '\(pattern)' tracked."
            lastError = nil
            await refresh()
        } catch {
            lastError = "Track failed: \(error.localizedDescription)"
        }
    }
}
