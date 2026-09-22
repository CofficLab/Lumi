import Foundation
import ProviderProject
import ProviderSkill

/// 同步项目列表与技能底座（插件贡献 + 内置）变化到 Skill 设置页 ViewModel。
///
/// 在插件组装层创建，初始化时写入初值并订阅 `ProjectProviding` 与
/// `SkillProviding` 变化；收到事件后**直接修改** `SkillSettingsViewModel`，
/// 不向外传回调。
@MainActor
final class SkillSettingsObserver {
    private let skillProvider: (any SkillProviding)?
    private let viewModel: SkillSettingsViewModel
    private var projectHandle: (any ProjectProvidingObserverHandle)?
    private var skillHandle: (any SkillProvidingObserverHandle)?

    init(
        projectProvider: (any ProjectProviding)?,
        skillProvider: (any SkillProviding)?,
        viewModel: SkillSettingsViewModel
    ) {
        self.skillProvider = skillProvider
        self.viewModel = viewModel

        viewModel.updateProjects(projectProvider?.projects ?? [])
        viewModel.updateBaseSkills(skillProvider?.allSkills() ?? [])

        projectHandle = projectProvider?.addObserver { [weak self] event in
            guard let self, case .projectsChanged(let projects) = event else { return }
            self.viewModel.updateProjects(projects)
        }
        skillHandle = skillProvider?.addObserver { [weak self] _ in
            guard let self else { return }
            self.viewModel.updateBaseSkills(self.skillProvider?.allSkills() ?? [])
        }
    }

    func cancel() {
        projectHandle?.cancel()
        projectHandle = nil
        skillHandle?.cancel()
        skillHandle = nil
    }
}
