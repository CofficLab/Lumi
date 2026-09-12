import AppKit
import Foundation
import ProviderProject
import SwiftUI

/// Agent Rules 设置页的唯一数据来源。
///
/// 负责项目列表、选中项目、规则加载/错误/刷新等业务状态；项目外部变化
/// 由 `AgentRulesProjectObserver` 直接写入本 ViewModel，View 只读取它。
@MainActor
final class AgentRulesViewModel: ObservableObject {
    // MARK: - Published State (供 View 展示)

    /// 项目目录列表（由 Observer 从 `ProjectProviding` 同步）。
    @Published private(set) var projects: [ProjectInfo] = []
    /// 当前选中的项目路径。
    @Published private(set) var selectedProjectPath: String?
    /// 当前项目的规则列表。
    @Published private(set) var rules: [AgentRuleMetadata] = []
    /// 是否正在加载规则。
    @Published private(set) var isLoading = false
    /// 加载错误信息。
    @Published private(set) var errorMessage: String?

    init() {}

    // MARK: - 派生状态

    var projectsSorted: [ProjectInfo] {
        projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var selectedProject: ProjectInfo? {
        guard let selectedProjectPath else { return nil }
        return projects.first { $0.path == selectedProjectPath }
    }

    // MARK: - Observer 写入

    /// 项目目录变化时由 Observer 调用。
    func updateProjects(_ newProjects: [ProjectInfo]) {
        projects = newProjects
        syncSelectionAfterProjectChange()
    }

    // MARK: - 用户意图

    func selectProject(path: String?) {
        selectedProjectPath = path
        Task { await reload() }
    }

    func refresh() {
        Task { await reload() }
    }

    func openRulesDirectory() {
        guard let projectPath = selectedProjectPath else { return }
        let url = getRulesDirectory(for: projectPath)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        _ = NSWorkspace.shared.open(url)
    }

    /// 首次出现时若无选中项目，默认选中第一个。
    func seedSelectionIfNeeded() {
        guard selectedProjectPath == nil else { return }
        selectedProjectPath = projects.first?.path
        if selectedProjectPath != nil {
            Task { await reload() }
        }
    }

    // MARK: - Data

    func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let projectPath = selectedProjectPath else {
            rules = []
            return
        }
        let rulesDirectory = getRulesDirectory(for: projectPath)

        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: rulesDirectory.path()) {
            rules = []
            return
        }

        do {
            rules = try await AgentRulesService.shared.listRules(projectPath: projectPath)
        } catch {
            errorMessage = error.localizedDescription
            rules = []
        }
    }

    private func syncSelectionAfterProjectChange() {
        if let selectedProjectPath, projects.contains(where: { $0.path == selectedProjectPath }) {
            return
        }
        selectedProjectPath = projects.first?.path
        if selectedProjectPath != nil {
            Task { await reload() }
        }
    }

    private func getRulesDirectory(for projectPath: String) -> URL {
        if projectPath.isEmpty {
            // Global rules directory
            let home = FileManager.default.homeDirectoryForCurrentUser
            return home.appendingPathComponent(".agent/rules")
        }
        let projectURL = URL(fileURLWithPath: projectPath)
        return projectURL.appendingPathComponent(".agent/rules")
    }
}
