import Foundation
import SwiftUI

/// Chat toolbar rules and detail state.
///
/// `AgentRulesToolbarProjectObserver` owns external project observation and
/// updates this model; toolbar views only read state and send user intents.
@MainActor
final class AgentRulesToolbarViewModel: ObservableObject {
    typealias RulesLoader = @Sendable (String) async throws -> [AgentRuleMetadata]
    typealias RuleLoader = @Sendable (String, String) async throws -> AgentRule

    @Published private(set) var currentProjectPath: String?
    @Published private(set) var rules: [AgentRuleMetadata] = []
    @Published private(set) var selectedRule: AgentRule?
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingSelectedRule = false

    private let loadRules: RulesLoader
    private let loadRule: RuleLoader
    private var projectGeneration = 0
    private var rulesRequestID = 0
    private var detailRequestID = 0
    private var rulesTask: Task<Void, Never>?
    private var detailTask: Task<Void, Never>?

    init(
        loadRules: @escaping RulesLoader = { path in
            try await AgentRulesService.shared.listRules(projectPath: path)
        },
        loadRule: @escaping RuleLoader = { path, filename in
            try await AgentRulesService.shared.readRule(projectPath: path, filename: filename)
        }
    ) {
        self.loadRules = loadRules
        self.loadRule = loadRule
    }

    /// Called by the project observer whenever the active project changes.
    func updateProject(path: String?) {
        let trimmedPath = path?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPath = trimmedPath.flatMap { $0.isEmpty ? nil : $0 }

        currentProjectPath = normalizedPath
        projectGeneration &+= 1
        rules = []
        selectedRule = nil
        isLoadingSelectedRule = false
        detailRequestID &+= 1
        detailTask?.cancel()
        detailTask = nil
        loadCurrentProjectRules()
    }

    func refresh() {
        loadCurrentProjectRules()
    }

    func selectRule(_ rule: AgentRuleMetadata) {
        guard let path = currentProjectPath else { return }
        detailRequestID &+= 1
        let requestID = detailRequestID
        let expectedProjectGeneration = self.projectGeneration
        detailTask?.cancel()
        selectedRule = nil
        isLoadingSelectedRule = true
        detailTask = Task { [weak self] in
            guard let self else { return }
            do {
                let detail = try await loadRule(path, rule.filename)
                guard !Task.isCancelled,
                      detailRequestID == requestID,
                      self.projectGeneration == expectedProjectGeneration,
                      currentProjectPath == path else { return }
                selectedRule = detail
            } catch {
                guard detailRequestID == requestID,
                      self.projectGeneration == expectedProjectGeneration else { return }
            }
            guard detailRequestID == requestID else { return }
            isLoadingSelectedRule = false
        }
    }

    func clearSelectedRule() {
        detailRequestID &+= 1
        detailTask?.cancel()
        detailTask = nil
        selectedRule = nil
        isLoadingSelectedRule = false
    }

    func cancel() {
        projectGeneration &+= 1
        rulesRequestID &+= 1
        detailRequestID &+= 1
        rulesTask?.cancel()
        detailTask?.cancel()
        rulesTask = nil
        detailTask = nil
        currentProjectPath = nil
        rules = []
        selectedRule = nil
        isLoading = false
        isLoadingSelectedRule = false
    }

    private func loadCurrentProjectRules() {
        rulesRequestID &+= 1
        let requestID = rulesRequestID
        let projectGeneration = self.projectGeneration
        rulesTask?.cancel()
        guard let path = currentProjectPath else {
            rules = []
            isLoading = false
            return
        }

        isLoading = true
        rulesTask = Task { [weak self] in
            guard let self else { return }
            do {
                let loadedRules = try await loadRules(path)
                guard !Task.isCancelled,
                      rulesRequestID == requestID,
                      self.projectGeneration == projectGeneration,
                      currentProjectPath == path else { return }
                rules = loadedRules
            } catch {
                guard rulesRequestID == requestID,
                      self.projectGeneration == projectGeneration,
                      currentProjectPath == path else { return }
                rules = []
            }
            guard rulesRequestID == requestID,
                  self.projectGeneration == projectGeneration else { return }
            isLoading = false
        }
    }
}
