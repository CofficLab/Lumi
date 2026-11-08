import Testing
import Foundation
import KitAgentTool
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
    let rulesURL = projectURL.appending(path: ".lumi/rules")
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
    let rulesURL = projectURL.appending(path: ".lumi/rules")
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
    @Test func createRuleWritesIntoLumiDirectory() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRulesTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    let rule = try await AgentRulesService.shared.createRule(
        projectPath: projectURL.path(),
        filename: "created",
        title: "Created Rule",
        content: "Body."
    )

    #expect(rule.filePath == projectURL.appending(path: ".lumi/rules/created.md").path)
    #expect(FileManager.default.fileExists(atPath: rule.filePath))
    #expect(!FileManager.default.fileExists(
        atPath: projectURL.appending(path: ".agent/rules/created.md").path
    ))
}

@MainActor
    @Test func listRulesStillReadsLegacyAgentDirectory() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRulesTests-\(UUID().uuidString)", isDirectory: true)
    let legacyRulesURL = projectURL.appending(path: ".agent/rules")
    try FileManager.default.createDirectory(at: legacyRulesURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    try "# Legacy Rule\n\nFrom the old directory.".write(
        to: legacyRulesURL.appending(path: "legacy.md"),
        atomically: true,
        encoding: .utf8
    )

    let rules = try await AgentRulesService.shared.listRules(projectPath: projectURL.path())
    let rule = try #require(rules.first)

    #expect(rule.filename == "legacy.md")
    #expect(rule.title == "Legacy Rule")
}

@MainActor
    @Test func listRulesMergesBothDirectoriesAndPrefersLumi() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRulesTests-\(UUID().uuidString)", isDirectory: true)
    let lumiRulesURL = projectURL.appending(path: ".lumi/rules")
    let legacyRulesURL = projectURL.appending(path: ".agent/rules")
    try FileManager.default.createDirectory(at: lumiRulesURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: legacyRulesURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    try "# Shared\n\nFrom .lumi.".write(
        to: lumiRulesURL.appending(path: "shared.md"),
        atomically: true,
        encoding: .utf8
    )
    try "# Shared\n\nFrom .agent.".write(
        to: legacyRulesURL.appending(path: "shared.md"),
        atomically: true,
        encoding: .utf8
    )
    try "# Only Legacy\n\nFrom .agent.".write(
        to: legacyRulesURL.appending(path: "only-legacy.md"),
        atomically: true,
        encoding: .utf8
    )

    let rules = try await AgentRulesService.shared.listRules(projectPath: projectURL.path())
    let filenames = Set(rules.map(\.filename))

    #expect(filenames == ["shared.md", "only-legacy.md"])
    let shared = try #require(rules.first { $0.filename == "shared.md" })
    #expect(
        URL(fileURLWithPath: shared.filePath).resolvingSymlinksInPath().path
            == lumiRulesURL.resolvingSymlinksInPath().appending(path: "shared.md").path
    )
}

@MainActor
    @Test func readRuleFallsBackToLegacyAgentDirectory() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRulesTests-\(UUID().uuidString)", isDirectory: true)
    let legacyRulesURL = projectURL.appending(path: ".agent/rules")
    try FileManager.default.createDirectory(at: legacyRulesURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    try "# Legacy Only\n\nKept in .agent.".write(
        to: legacyRulesURL.appending(path: "legacy-only.md"),
        atomically: true,
        encoding: .utf8
    )

    let rule = try await AgentRulesService.shared.readRule(
        projectPath: projectURL.path(),
        filename: "legacy-only.md"
    )

    #expect(rule.title == "Legacy Only")
    #expect(rule.filePath == legacyRulesURL.appending(path: "legacy-only.md").path)
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

/// `.lumi/rules` 被普通文件占住时，即使 `.agent/rules` 里有可用规则，也必须报错，
/// 不能把「读不到」伪装成空列表或不完整列表。
@MainActor
    @Test func listRulesThrowsWhenRulesPathIsNotADirectory() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRulesTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    let legacyRulesURL = projectURL.appending(path: ".agent/rules")
    try FileManager.default.createDirectory(at: legacyRulesURL, withIntermediateDirectories: true)
    try "# Legacy\n\nStill readable.".write(
        to: legacyRulesURL.appending(path: "legacy.md"),
        atomically: true,
        encoding: .utf8
    )
    try FileManager.default.createDirectory(
        at: projectURL.appending(path: ".lumi"),
        withIntermediateDirectories: true
    )
    try "not a directory".write(
        to: projectURL.appending(path: ".lumi/rules"),
        atomically: true,
        encoding: .utf8
    )

    await #expect(throws: AgentRulesError.self) {
        _ = try await AgentRulesService.shared.listRules(projectPath: projectURL.path())
    }
}

/// 目录存在但无法枚举时必须上抛，而不是成功返回 count=0。
@MainActor
    @Test func listRulesThrowsWhenRulesDirectoryIsUnreadable() async throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("AgentRulesTests-\(UUID().uuidString)", isDirectory: true)
    let rulesURL = projectURL.appending(path: ".lumi/rules")
    try FileManager.default.createDirectory(at: rulesURL, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: rulesURL.path()
        )
        try? FileManager.default.removeItem(at: projectURL)
    }

    try "# Style\n\nHidden by permissions.".write(
        to: rulesURL.appending(path: "style.md"),
        atomically: true,
        encoding: .utf8
    )
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o000],
        ofItemAtPath: rulesURL.path()
    )

    await #expect(throws: AgentRulesError.self) {
        _ = try await AgentRulesService.shared.listRules(projectPath: projectURL.path())
    }
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

    @Test("Rules change notification reloads only the current project")
    func rulesChangeNotificationRefreshesMatchingProject() async throws {
        let loader = SequenceRulesLoader()
        let projectProvider = DefaultProjectProvider()
        let projectPath = "/tmp/agent-rules-notification"
        let viewModel = AgentRulesToolbarViewModel(loadRules: { _ in await loader.load() })
        let observer = AgentRulesToolbarProjectObserver(
            projectProvider: projectProvider,
            viewModel: viewModel
        )
        defer {
            observer.cancel()
            viewModel.cancel()
        }

        try await projectProvider.openProject(at: projectPath)
        await waitUntil { viewModel.rules.map(\.id) == ["call-1"] }

        // 其他项目的变更不应触发当前工具栏重新加载。
        NotificationCenter.default.post(
            name: .agentRulesDidChange,
            object: nil,
            userInfo: [AgentRulesChange.projectPathKey: "/tmp/agent-rules-elsewhere"]
        )
        try? await Task.sleep(for: .milliseconds(30))
        #expect(viewModel.rules.map(\.id) == ["call-1"])

        // 当前项目的变化必须触发一次重新读取。
        NotificationCenter.default.post(
            name: .agentRulesDidChange,
            object: nil,
            userInfo: [AgentRulesChange.projectPathKey: projectPath]
        )
        await waitUntil { viewModel.rules.map(\.id) == ["call-2"] }
        #expect(viewModel.rules.map(\.id) == ["call-2"])
    }

    @Test("create_agent_rule posts a rules change notification for its project")
    func createRuleToolPostsChangeNotification() async throws {
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentRulesNotify-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        try await confirmation("rules change notification") { confirm in
            let token = NotificationCenter.default.addObserver(
                forName: .agentRulesDidChange,
                object: nil,
                queue: nil
            ) { notification in
                guard notification.userInfo?[AgentRulesChange.projectPathKey] as? String == projectURL.path else {
                    return
                }
                confirm()
            }
            defer { NotificationCenter.default.removeObserver(token) }

            _ = try await CreateAgentRuleTool().execute(arguments: [
                "project_path": ToolArgument(projectURL.path),
                "filename": ToolArgument("notify"),
                "title": ToolArgument("Notify"),
            ])
        }

        #expect(FileManager.default.fileExists(atPath: projectURL.appending(path: ".lumi/rules/notify.md").path))
    }

    @Test("Rule ID strips only the final extension, keeping inner .md occurrences")
    func ruleIdKeepsInnerMarkdownExtensions() async throws {
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentRulesIDs-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let service = AgentRulesService()
        let first = try await service.createRule(
            projectPath: projectURL.path,
            filename: "foo",
            title: "First",
            content: ""
        )
        let second = try await service.createRule(
            projectPath: projectURL.path,
            filename: "foo.md.md",
            title: "Second",
            content: ""
        )

        #expect(first.id == "foo")
        #expect(second.id == "foo.md")

        let rules = try await service.listRules(projectPath: projectURL.path)
        #expect(rules.count == 2)
        #expect(Set(rules.map(\.id)) == ["foo", "foo.md"])

        let read = try await service.readRule(projectPath: projectURL.path, filename: "foo.md.md")
        #expect(read.id == "foo.md")
    }

    @Test("listRules skips .md directories instead of failing the whole list")
    func listRulesSkipsMarkdownDirectories() async throws {
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentRulesDirEntry-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let rulesDirectory = projectURL.appending(path: ".lumi/rules")
        try FileManager.default.createDirectory(
            at: rulesDirectory.appending(path: "archive.md"),
            withIntermediateDirectories: true
        )
        try "# Style\n\nKeep rules readable.\n"
            .write(to: rulesDirectory.appending(path: "style.md"), atomically: true, encoding: .utf8)

        let rules = try await AgentRulesService().listRules(projectPath: projectURL.path)

        #expect(rules.map(\.filename) == ["style.md"])
        #expect(rules.first?.id == "style")
    }

    @Test("createRule reports the heading actually written to disk")
    func createRuleTitleMatchesWrittenContent() async throws {
        let projectURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AgentRulesTitle-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: projectURL) }

        let service = AgentRulesService()
        let embedded = try await service.createRule(
            projectPath: projectURL.path,
            filename: "heading",
            title: "Requested Title",
            content: "# Embedded Title\n\nBody"
        )

        #expect(embedded.title == "Embedded Title")

        let listed = try await service.listRules(projectPath: projectURL.path)
        #expect(listed.first(where: { $0.filename == "heading.md" })?.title == embedded.title)

        // 内容没有一级标题时仍使用参数标题，保持原行为。
        let normal = try await service.createRule(
            projectPath: projectURL.path,
            filename: "normal",
            title: "Requested Title",
            content: "Body"
        )
        #expect(normal.title == "Requested Title")
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

/// 每次加载返回不同 id，便于断言工具栏确实重新读取了规则。
private actor SequenceRulesLoader {
    private var calls = 0

    func load() -> [AgentRuleMetadata] {
        calls += 1
        let id = "call-\(calls)"
        return [
            AgentRuleMetadata(
                id: id,
                filename: "\(id).md",
                title: id,
                description: "",
                fileSize: 0,
                modifiedAt: .distantPast,
                filePath: "/tmp/\(id).md"
            ),
        ]
    }
}
