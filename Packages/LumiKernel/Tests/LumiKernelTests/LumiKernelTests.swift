import Foundation
import Testing
import SwiftUI
@testable import LumiKernel

@Suite("LumiKernel Tests")
@MainActor
struct LumiKernelTests {

    @Test("Service registration and resolution")
    func testServiceRegistration() async throws {
        let kernel = LumiKernel()

        // 测试服务注册
        let storage = MockStorageService()
        kernel.registerService(StorageProviding.self, storage)

        // 测试服务解析
        let resolved = kernel.resolveService(StorageProviding.self)
        #expect(resolved != nil)
    }

    @Test("Conversation input service can be registered and resolved")
    func testConversationInputServiceRegistration() async throws {
        let kernel = LumiKernel()
        let input = MockConversationInputService()

        kernel.registerConversationInputService(input)

        let resolved = kernel.conversationInput
        #expect(resolved != nil)
        #expect(resolved as? MockConversationInputService === input)
    }

    @Test("Conversation input state is shared through kernel")
    func testConversationInputStateSharedThroughKernel() async throws {
        let kernel = LumiKernel()
        let input = MockConversationInputService()
        kernel.registerConversationInputService(input)

        kernel.conversationInput?.text = "hello kernel"
        kernel.conversationInput?.inputHeight = 120
        kernel.conversationInput?.isInputFocused = true
        kernel.conversationInput?.inputCursorPosition = 3
        kernel.conversationInput?.errorMessage = "boom"

        #expect(input.text == "hello kernel")
        #expect(input.inputHeight == 120)
        #expect(input.isInputFocused == true)
        #expect(input.inputCursorPosition == 3)
        #expect(input.errorMessage == "boom")
    }

    @Test("Conversation input can accept conversation file references")
    func testConversationInputConversationReferences() async throws {
        let kernel = LumiKernel()
        let input = MockConversationInputService()
        kernel.registerConversationInputService(input)

        let fileA = URL(fileURLWithPath: "/tmp/A.swift")
        let fileB = URL(fileURLWithPath: "/tmp/B.swift")

        kernel.conversationInput?.addToConversation(fileURLs: [fileA, fileB], windowId: nil)

        #expect(input.text == """
        Files to add to conversation:
        - /tmp/A.swift
        - /tmp/B.swift
        """)
        #expect(input.isInputFocused == true)
    }

    @Test("Project service can store and expose current file")
    func testProjectServiceCurrentFile() async throws {
        let kernel = LumiKernel()
        let project = MockProjectService()
        try kernel.registerProject(project)

        let fileURL = URL(fileURLWithPath: "/tmp/Project/Sources/Main.swift")
        kernel.project?.updateCurrentFile(fileURL)

        #expect(project.openFileURLs == [fileURL.standardizedFileURL])
        #expect(project.currentFileURL == fileURL.standardizedFileURL)
        #expect(kernel.project?.currentFileURL == fileURL.standardizedFileURL)
        #expect(kernel.project?.openFileURLs == [fileURL.standardizedFileURL])
    }

    @Test("Plugin manager registers typed editor plugins through EditorProviding")
    func testPluginManagerRegistersTypedEditorPlugins() async throws {
        let kernel = LumiKernel()
        let editor = MockEditorProvider()
        try kernel.registerEditor(editor)

        let manager = BuiltinPluginManager()
        let swiftLanguage = MockEditorRuntimePlugin(id: "swift", name: "Swift", order: 20)
        let goLanguage = MockEditorRuntimePlugin(id: "go", name: "Go", order: 10)
        try await manager.initializePlugins([
            MockLumiPlugin(id: "swift-plugin", order: 20, editorRuntimePlugins: [swiftLanguage]),
            MockLumiPlugin(id: "go-plugin", order: 10, editorRuntimePlugins: [goLanguage]),
        ], kernel: kernel)

        manager.registerEditorPlugins(in: kernel)

        #expect(editor.replacedPluginIDs == ["go", "swift"])
    }

    @Test("Plugin manager withdraws disabled typed editor plugins on rebuild")
    func testPluginManagerWithdrawsDisabledEditorPluginsOnRebuild() async throws {
        let kernel = LumiKernel()
        let editor = MockEditorProvider()
        try kernel.registerEditor(editor)

        let manager = BuiltinPluginManager()
        try await manager.initializePlugins([
            MockLumiPlugin(
                id: "enabled-language",
                order: 10,
                policy: .alwaysOn,
                editorRuntimePlugins: [MockEditorRuntimePlugin(id: "swift", name: "Swift", order: 10)]
            ),
            MockLumiPlugin(
                id: "disabled-language",
                order: 20,
                policy: .disabled,
                editorRuntimePlugins: [MockEditorRuntimePlugin(id: "go", name: "Go", order: 20)]
            ),
        ], kernel: kernel)

        manager.rebuildAllContributions(in: kernel)

        #expect(editor.replacedPluginIDs == ["swift"])
    }
}

// MARK: - Mock Services

/// Mock 存储服务实现
@MainActor
private final class MockStorageService: StorageProviding {
    var dataRootDirectory: URL {
        FileManager.default.temporaryDirectory
    }

    func pluginDataDirectory(for pluginID: String) -> URL {
        dataRootDirectory.appendingPathComponent("Plugins/\(pluginID)")
    }

    func coreDataDirectory() -> URL {
        dataRootDirectory.appendingPathComponent("Core")
    }
}

@MainActor
private final class MockProjectService: ProjectProviding {
    @Published var currentProject: ProjectInfo?
    @Published var openFileURLs: [URL] = []
    @Published var currentFileURL: URL?
    @Published var projects: [ProjectInfo] = []

    func openProject(at path: String) async throws {
        let url = URL(fileURLWithPath: path)
        currentProject = ProjectInfo(name: url.lastPathComponent, path: path)
        currentFileURL = nil
    }

    func updateCurrentFile(_ fileURL: URL?) {
        let standardizedURL = fileURL?.standardizedFileURL
        currentFileURL = standardizedURL
        guard let standardizedURL else { return }
        updateOpenFiles(openFileURLs + [standardizedURL])
    }

    func updateOpenFiles(_ fileURLs: [URL]) {
        var uniqueURLs: [URL] = []
        for fileURL in fileURLs {
            let standardizedURL = fileURL.standardizedFileURL
            if !uniqueURLs.contains(standardizedURL) {
                uniqueURLs.append(standardizedURL)
            }
        }
        openFileURLs = uniqueURLs
    }

    func closeProject() async {
        currentProject = nil
        openFileURLs = []
        currentFileURL = nil
    }

    func refreshProjects() async throws {}
}

@MainActor
private final class MockConversationInputService: ConversationInputProviding {
    @Published var text: String = ""
    @Published var inputHeight: CGFloat = 64
    @Published var isInputFocused: Bool = false
    @Published var inputCursorPosition: Int = 0
    @Published var errorMessage: String?

    var isSendingValue: Bool = false
    var canSendValue: Bool = true
    var stopCallCount: Int = 0
    var sendCallCount: Int = 0

    func isSending(kernel: LumiKernel) -> Bool {
        isSendingValue
    }

    func canSend(kernel: LumiKernel) -> Bool {
        canSendValue
    }

    func send(kernel: LumiKernel) {
        sendCallCount += 1
    }

    func stop(kernel: LumiKernel) {
        stopCallCount += 1
    }

    func addToConversation(fileURLs: [URL], windowId: UUID?) {
        let paths = fileURLs.map { $0.standardizedFileURL.path }
        guard !paths.isEmpty else { return }

        let referenceBlock = (["Files to add to conversation:"] + paths.map { "- \($0)" })
            .joined(separator: "\n")
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            text = referenceBlock
        } else {
            text = text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n" + referenceBlock
        }
        isInputFocused = true
    }
}

@MainActor
private final class MockEditorProvider: EditorProviding {
    var currentFilePath: String?
    var currentThemeId: String = "default"
    var allEditorThemes: [EditorThemeInfo] = []
    var replacedPluginIDs: [String] = []

    func openFile(at path: String) async throws {
        currentFilePath = path
    }

    func closeFile(at path: String) async {
        if currentFilePath == path {
            currentFilePath = nil
        }
    }

    func setCurrentTheme(_ themeId: String) throws {
        currentThemeId = themeId
    }

    func registerEditorTheme(_ theme: EditorThemeInfo) {
        allEditorThemes.append(theme)
    }

    func unregisterEditorTheme(themeId: String) {
        allEditorThemes.removeAll { $0.id == themeId }
    }

    func registerEditorPlugin(_ plugin: any EditorPlugin) {
        replacedPluginIDs.append(plugin.id)
    }

    func replaceEditorPlugins(_ plugins: [any EditorPlugin]) {
        replacedPluginIDs = plugins.map(\.id)
    }
}

@MainActor
private final class MockEditorRuntimePlugin: EditorPlugin {
    let id: String
    let name: String
    let order: Int

    init(id: String, name: String, order: Int) {
        self.id = id
        self.name = name
        self.order = order
    }

    func registerExtensions(into registrar: any EditorExtensionRegistrar) {}
}

@MainActor
private final class MockLumiPlugin: LumiPlugin {
    let id: String
    let name: String
    let order: Int
    let policy: LumiPluginPolicy
    private let editorRuntimePlugins: [any EditorPlugin]

    init(
        id: String,
        name: String? = nil,
        order: Int,
        policy: LumiPluginPolicy = .alwaysOn,
        editorRuntimePlugins: [any EditorPlugin]
    ) {
        self.id = id
        self.name = name ?? id
        self.order = order
        self.policy = policy
        self.editorRuntimePlugins = editorRuntimePlugins
    }

    func onBoot(kernel: LumiKernel) async throws {}
    func onReady(kernel: LumiKernel) async throws {}
    func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
    func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    func editorPlugins(kernel: LumiKernel) -> [any EditorPlugin] { editorRuntimePlugins }
}
