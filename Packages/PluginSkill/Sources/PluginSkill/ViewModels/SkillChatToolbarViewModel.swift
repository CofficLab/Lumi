import Foundation
import ProviderSkill
import SwiftUI

/// Chat toolbar skill state.
///
/// Project and contributor changes are forwarded by `SkillChatToolbarObserver`;
/// the toolbar view only reads this model.
@MainActor
final class SkillChatToolbarViewModel: ObservableObject {
    @Published private(set) var currentProjectPath: String?
    @Published private(set) var skills: [SkillMetadata] = []
    @Published private(set) var isLoading = false

    private let service: SkillService
    private var baseSkills: [SkillMetadata] = []
    private var requestID = 0
    private var refreshTask: Task<Void, Never>?

    init(service: SkillService = .shared) {
        self.service = service
    }

    /// Syncs a provider snapshot and reloads the toolbar list.
    func update(
        projectPath: String?,
        baseSkills: [SkillMetadata],
        invalidateProjectCache: Bool = false,
        invalidateAllCache: Bool = false
    ) {
        let trimmedPath = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = trimmedPath.flatMap { $0.isEmpty ? nil : $0 }
        guard currentProjectPath != path
                || self.baseSkills != baseSkills
                || invalidateProjectCache
                || invalidateAllCache else { return }

        currentProjectPath = path
        self.baseSkills = baseSkills
        requestID &+= 1
        let requestID = self.requestID
        refreshTask?.cancel()

        // Immediately remove the previous project's entries while preserving
        // global/plugin skills that are valid without an open project.
        skills = baseSkills
        guard let path else {
            refreshTask = nil
            isLoading = false
            return
        }

        isLoading = true
        refreshTask = Task { [weak self] in
            guard let self else { return }
            if invalidateAllCache {
                await service.invalidateAllCache()
            } else if invalidateProjectCache {
                await service.invalidateCache(projectPath: path)
            }
            guard !Task.isCancelled, self.requestID == requestID else { return }
            let loadedSkills = await service.listSkills(projectPath: path, baseSkills: baseSkills)
            guard !Task.isCancelled,
                  self.requestID == requestID,
                  self.currentProjectPath == path else { return }
            skills = loadedSkills
            isLoading = false
        }
    }

    func cancel() {
        requestID &+= 1
        refreshTask?.cancel()
        refreshTask = nil
        currentProjectPath = nil
        baseSkills = []
        skills = []
        isLoading = false
    }
}
