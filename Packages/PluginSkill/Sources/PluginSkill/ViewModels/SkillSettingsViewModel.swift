import AppKit
import Foundation
import ProviderProject
import ProviderSkill
import SwiftUI

/// Skill 设置页的唯一数据来源。
///
/// 负责项目列表、选中项目、技能加载/错误/刷新等业务状态；项目与技能底座
/// 的外部变化由 `SkillSettingsObserver` 直接写入本 ViewModel，View 只读取它。
///
/// 技能分两组展示：
/// - `projectSkills`：当前项目 `.agent/skills` 目录下的技能（项目层）；
/// - `baseSkills`：插件贡献 + 内置的通用技能（`SkillProviding` 聚合底座）。
@MainActor
final class SkillSettingsViewModel: ObservableObject {
    // MARK: - Published State (供 View 展示)

    /// 项目目录列表（由 Observer 从 `ProjectProviding` 同步）。
    @Published private(set) var projects: [ProjectInfo] = []
    /// 当前选中的项目路径。
    @Published private(set) var selectedProjectPath: String?
    /// 当前项目的技能列表（`.agent/skills` 目录，项目层）。
    @Published private(set) var projectSkills: [SkillMetadata] = []
    /// 通用技能底座（插件贡献 + 内置，由 `SkillProviding` 聚合）。
    @Published private(set) var baseSkills: [SkillMetadata] = []
    /// 是否正在加载项目技能。
    @Published private(set) var isLoading = false
    /// 加载错误信息。
    @Published private(set) var errorMessage: String?

    private let service: SkillService

    init(service: SkillService = .shared) {
        self.service = service
    }

    // MARK: - 派生状态

    var projectsSorted: [ProjectInfo] {
        projects.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var selectedProject: ProjectInfo? {
        guard let selectedProjectPath else { return nil }
        return projects.first { $0.path == selectedProjectPath }
    }

    /// 全部可用技能数（项目层 + 通用底座），用于 header 计数。
    var availableSkillCount: Int {
        projectSkills.count + baseSkills.count
    }

    // MARK: - Observer 写入

    /// 项目目录变化时由 Observer 调用。
    func updateProjects(_ newProjects: [ProjectInfo]) {
        projects = newProjects
        syncSelectionAfterProjectChange()
    }

    /// 技能底座（插件贡献 + 内置）变化时由 Observer 调用。
    func updateBaseSkills(_ newBaseSkills: [SkillMetadata]) {
        baseSkills = newBaseSkills
    }

    // MARK: - 用户意图

    func selectProject(path: String?) {
        selectedProjectPath = path
        Task { await reload() }
    }

    func refresh() {
        Task { await reload() }
    }

    func openSkillsDirectory() {
        guard let projectPath = selectedProjectPath else { return }
        let url = getSkillsDirectory(for: projectPath)
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
            projectSkills = []
            return
        }

        // 项目层技能（不叠加通用底座，避免混入插件贡献 / 内置技能）。
        // 目录不存在时由 service 层（SkillDirectoryLoader）返回空列表。
        let skills = await service.listSkills(projectPath: projectPath, baseSkills: [])
        projectSkills = skills
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

    private func getSkillsDirectory(for projectPath: String) -> URL {
        URL(fileURLWithPath: projectPath).appendingPathComponent(".agent/skills")
    }
}
