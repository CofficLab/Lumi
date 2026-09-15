import Foundation
import ProviderProject
import ProviderSkill

/// Synchronizes active-project and contributed-skill changes into the toolbar VM.
@MainActor
final class SkillChatToolbarObserver {
    private let projectProvider: (any ProjectProviding)?
    private let skillProvider: (any SkillProviding)?
    private let viewModel: SkillChatToolbarViewModel
    private var projectHandle: (any ProjectProvidingObserverHandle)?
    private var skillHandle: (any SkillProvidingObserverHandle)?

    init(
        projectProvider: (any ProjectProviding)?,
        skillProvider: (any SkillProviding)?,
        viewModel: SkillChatToolbarViewModel
    ) {
        self.projectProvider = projectProvider
        self.skillProvider = skillProvider
        self.viewModel = viewModel

        sync(projectPath: projectProvider?.currentProject?.path)
        projectHandle = projectProvider?.addObserver { [weak self] event in
            guard let self, case let .currentProjectChanged(project, _) = event else { return }
            self.sync(projectPath: project?.path, invalidateProjectCache: true)
        }
        skillHandle = skillProvider?.addObserver { [weak self] _ in
            guard let self else { return }
            self.sync(
                projectPath: self.projectProvider?.currentProject?.path,
                invalidateAllCache: true
            )
        }
    }

    func cancel() {
        projectHandle?.cancel()
        projectHandle = nil
        skillHandle?.cancel()
        skillHandle = nil
    }

    private func sync(
        projectPath: String?,
        invalidateProjectCache: Bool = false,
        invalidateAllCache: Bool = false
    ) {
        viewModel.update(
            projectPath: projectPath,
            baseSkills: skillProvider?.allSkills() ?? [],
            invalidateProjectCache: invalidateProjectCache,
            invalidateAllCache: invalidateAllCache
        )
    }
}
