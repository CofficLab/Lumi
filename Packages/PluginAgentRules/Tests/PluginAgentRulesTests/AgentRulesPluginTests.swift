import Testing
import Foundation
import KernelCore
import ProviderChatSection
import ProviderProject
@testable import PluginAgentRules

@MainActor
    @Test func packageLoads() async throws {
    #expect(AgentRulesPlugin().id == "com.coffic.lumi.plugin.agent-rules")
}

@MainActor
    @Test func pluginHasRequiredMetadata() throws {
    let plugin = AgentRulesPlugin()
    #expect(plugin.id == "com.coffic.lumi.plugin.agent-rules")
    #expect(plugin.name.isEmpty == false)
    #expect(plugin.order == 50)
    #expect(plugin.metadata.policy == .alwaysOn)
    #expect(plugin.metadata.category == .general)
    #expect(plugin.metadata.stage == .stable)
    #expect(AgentRulesPlugin.agentTools.count == 2)
}

@MainActor
    @Test func localStoreQuarantinesInvalidSettingsFileAndRecovers() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRulesLocalStore-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let settingsURL = directory.appending(path: "AgentRules.plist")
    let corruptURL = directory.appending(path: "AgentRules.corrupt.plist")
    let invalidData = Data("not a plist".utf8)
    try invalidData.write(to: settingsURL)

    let store = AgentRulesPluginLocalStore(settingsDirectory: directory)

    #expect(store.string(forKey: "rulesDirectoryPath") == nil)
    #expect((try? Data(contentsOf: corruptURL)) == invalidData)
    #expect(store.set("/tmp/.agent/rules", forKey: "rulesDirectoryPath") == true)

    let reloadedStore = AgentRulesPluginLocalStore(settingsDirectory: directory)
    #expect(reloadedStore.string(forKey: "rulesDirectoryPath") == "/tmp/.agent/rules")
}

@MainActor
    @Test func localStoreReportsFailureWhenSettingsDirectoryIsBlocked() throws {
    let tempRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRulesLocalStore-Blocked-\(UUID().uuidString)", isDirectory: true)
    let blockedDirectory = tempRoot.appending(path: "settings")
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let store = AgentRulesPluginLocalStore(settingsDirectory: blockedDirectory)

    #expect(store.set("/tmp/.agent/rules", forKey: "rulesDirectoryPath") == false)
    #expect(store.string(forKey: "rulesDirectoryPath") == nil)
}

@MainActor
    @Test func listRulesReadsUTF16MarkdownMetadata() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRulesTests-\(UUID().uuidString)", isDirectory: true)
    let rulesURL = projectURL.appending(path: ".agent/rules")
    try FileManager.default.createDirectory(at: rulesURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    let ruleURL = rulesURL.appending(path: "style.md")
    try """
    # Coding Style

    Prefer clear names.
    """.write(to: ruleURL, atomically: true, encoding: .utf16)

    let rules = try await AgentRulesService.shared.listRules(projectPath: projectURL.path())
    let rule = try #require(rules.first)

    #expect(rule.filename == "style.md")
    #expect(rule.title == "Coding Style")
}

@MainActor
    @Test func readRuleReturnsUTF16MarkdownContent() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRulesTests-\(UUID().uuidString)", isDirectory: true)
    let rulesURL = projectURL.appending(path: ".agent/rules")
    try FileManager.default.createDirectory(at: rulesURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    let content = """
    # Review Rules

    Check edge cases before shipping.
    """
    try content.write(to: rulesURL.appending(path: "review.md"), atomically: true, encoding: .utf16)

    let rule = try await AgentRulesService.shared.readRule(projectPath: projectURL.path(), filename: "review.md")

    #expect(rule.title == "Review Rules")
    #expect(rule.content == content)
}

@MainActor
    @Test func normalizedLimitCoercesAndClamps() throws {
    #expect(ListAgentRulesTool.normalizedLimit(nil) == nil)
    #expect(ListAgentRulesTool.normalizedLimit(5) == 5)
    #expect(ListAgentRulesTool.normalizedLimit(0) == 0)
    #expect(ListAgentRulesTool.normalizedLimit(-10) == 0)
    #expect(ListAgentRulesTool.normalizedLimit(500) == 100)
    #expect(ListAgentRulesTool.normalizedLimit(3.9) == 3)
    #expect(ListAgentRulesTool.normalizedLimit(-5.0) == 0)
    #expect(ListAgentRulesTool.normalizedLimit("42") == 42)
    #expect(ListAgentRulesTool.normalizedLimit("abc") == nil)
    #expect(ListAgentRulesTool.normalizedLimit("") == nil)
    #expect(ListAgentRulesTool.normalizedLimit("  ") == nil)
}

@Suite("AgentRulesToolbar")
@MainActor
struct AgentRulesToolbarTests {
    @Test("Plugin toolbar is registered and removed with its project observer")
    func pluginOwnsToolbarLifecycle() async throws {
        let kernel = KernelCoreContainer()
        let projectProvider = DefaultProjectProvider()
        let chatProvider = DefaultChatSectionProviding()
        try kernel.registerProvider((any ProjectProviding).self, projectProvider)
        try kernel.registerProvider((any ChatSectionProviding).self, chatProvider)
        let plugin = AgentRulesPlugin()

        try plugin.onBoot(kernel: kernel)
        #expect(chatProvider.barItems.map(\.id) == ["com.coffic.lumi.plugin.agent-rules.toolbar"])
        try await projectProvider.openProject(at: "/tmp/agent-rules-plugin")

        try plugin.onShutdown(kernel: kernel)
        #expect(chatProvider.barItems.isEmpty)
        try await projectProvider.openProject(at: "/tmp/agent-rules-after-shutdown")
    }

    @Test("Current project changes replace toolbar rules and closing clears them")
    func projectObserverUpdatesToolbarViewModel() async throws {
        let projectProvider = DefaultProjectProvider()
        let firstPath = "/tmp/agent-rules-first"
        let secondPath = "/tmp/agent-rules-second"
        let projectRules = [
            firstPath: [makeMetadata(id: "first", filename: "first.md")],
            secondPath: [makeMetadata(id: "second", filename: "second.md")],
        ]
        let viewModel = AgentRulesToolbarViewModel(loadRules: { path in
            projectRules[path] ?? []
        })
        let observer = AgentRulesToolbarProjectObserver(
            projectProvider: projectProvider,
            viewModel: viewModel
        )

        try await projectProvider.openProject(at: firstPath)
        await waitUntil { viewModel.rules.map(\.id) == ["first"] }
        #expect(viewModel.currentProjectPath == firstPath)

        try await projectProvider.openProject(at: secondPath)
        #expect(viewModel.currentProjectPath == secondPath)
        #expect(viewModel.rules.isEmpty)
        await waitUntil { viewModel.rules.map(\.id) == ["second"] }

        await projectProvider.closeProject()
        #expect(viewModel.currentProjectPath == nil)
        #expect(viewModel.rules.isEmpty)
        #expect(viewModel.isLoading == false)

        observer.cancel()
        try await projectProvider.openProject(at: "/tmp/agent-rules-ignored")
        #expect(viewModel.currentProjectPath == nil)
    }

    @Test("Rule details load from the project that owns the selected rule")
    func selectedRuleUsesViewModelProjectPath() async throws {
        let projectProvider = DefaultProjectProvider()
        let projectPath = "/tmp/agent-rules-detail"
        let metadata = makeMetadata(id: "guide", filename: "guide.md")
        let viewModel = AgentRulesToolbarViewModel(
            loadRules: { _ in [metadata] },
            loadRule: { path, filename in
                AgentRule(
                    id: "guide",
                    filename: filename,
                    title: "Guide",
                    description: "",
                    fileSize: 0,
                    createdAt: .distantPast,
                    modifiedAt: .distantPast,
                    filePath: "\(path)/.agent/rules/\(filename)",
                    content: path
                )
            }
        )
        let observer = AgentRulesToolbarProjectObserver(
            projectProvider: projectProvider,
            viewModel: viewModel
        )

        try await projectProvider.openProject(at: projectPath)
        await waitUntil { viewModel.rules.count == 1 }
        viewModel.selectRule(metadata)
        await waitUntil { viewModel.selectedRule != nil }

        #expect(viewModel.selectedRule?.filePath == "\(projectPath)/.agent/rules/guide.md")
        #expect(viewModel.selectedRule?.content == projectPath)

        observer.cancel()
    }

    @Test("A late rule-list response cannot replace the newly selected project")
    func staleProjectLoadIsIgnored() async throws {
        let projectProvider = DefaultProjectProvider()
        let firstPath = "/tmp/agent-rules-slow"
        let secondPath = "/tmp/agent-rules-fast"
        let firstRule = makeMetadata(id: "slow", filename: "slow.md")
        let secondRule = makeMetadata(id: "fast", filename: "fast.md")
        let viewModel = AgentRulesToolbarViewModel(loadRules: { path in
            if path == firstPath {
                try? await Task.sleep(for: .milliseconds(40))
                return [firstRule]
            }
            return [secondRule]
        })
        let observer = AgentRulesToolbarProjectObserver(
            projectProvider: projectProvider,
            viewModel: viewModel
        )

        try await projectProvider.openProject(at: firstPath)
        try await projectProvider.openProject(at: secondPath)
        await waitUntil { viewModel.rules.map(\.id) == ["fast"] }
        try? await Task.sleep(for: .milliseconds(50))

        #expect(viewModel.currentProjectPath == secondPath)
        #expect(viewModel.rules.map(\.id) == ["fast"])

        observer.cancel()
    }

    private func makeMetadata(id: String, filename: String) -> AgentRuleMetadata {
        AgentRuleMetadata(
            id: id,
            filename: filename,
            title: id,
            description: "",
            fileSize: 0,
            modifiedAt: .distantPast,
            filePath: "/tmp/\(filename)"
        )
    }

    private func waitUntil(
        iterations: Int = 100,
        condition: @MainActor () -> Bool
    ) async {
        for _ in 0..<iterations {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}
