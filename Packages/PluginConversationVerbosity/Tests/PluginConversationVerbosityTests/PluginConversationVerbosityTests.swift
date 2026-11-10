import Foundation
import Testing
import KernelCore
import ProviderChatSection
import ProviderConversation

@testable import PluginConversationVerbosity

@Suite("PluginConversationVerbosity")
@MainActor
struct PluginConversationVerbosityTests {
    private func makeKernel() throws -> (KernelCoreContainer, DefaultConversationManager, DefaultChatSectionProviding) {
        let kernel = KernelCoreContainer()
        let conversations = DefaultConversationManager()
        let chat = DefaultChatSectionProviding()
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        try kernel.registerProvider((any ChatSectionProviding).self, chat)
        return (kernel, conversations, chat)
    }

    @Test("Verbosity 插件注册工具栏按钮并创建 Adapter + ObservationBox")
    func verbosityRegistersToolbarButton() throws {
        let (kernel, _, chat) = try makeKernel()

        let plugin = ConversationVerbosityPlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any ConversationManaging).self) != nil)
        #expect(chat.barItems.count == 1)
    }

    @Test("CapabilityAdapter 收窄为 Verbosity 最小协议")
    func capabilityAdapterExposesVerbosityOnly() {
        let conversations = DefaultConversationManager()
        conversations.setGlobalVerbosity(.detailed)
        let adapter = ConversationVerbosityCapabilityAdapter(conversations: conversations)

        #expect(adapter.globalVerbosity == .detailed)
        adapter.setGlobalVerbosity(.brief)
        #expect(conversations.globalVerbosity == .brief)
    }

    @Test("Observer 直接更新 ViewModel 并支持取消")
    func observerWritesViewModelDirectlyAndSupportsCancel() throws {
        let conversations = DefaultConversationManager()
        let adapter = ConversationVerbosityCapabilityAdapter(conversations: conversations)
        let viewModel = VerbosityViewModel(capability: adapter)
        let observer = VerbosityObserver(capability: adapter, viewModel: viewModel)

        // 初值写入
        #expect(viewModel.selectedVerbosity == .defaultVerbosity)

        let revisionAfterBoot = viewModel.observationRevision
        _ = try conversations.createConversation(title: nil, projectPath: nil, providerID: nil, modelName: nil)
        #expect(viewModel.observationRevision > revisionAfterBoot)

        observer.cancel()
        let revisionAfterCancel = viewModel.observationRevision
        conversations.setGlobalVerbosity(.detailed)
        #expect(viewModel.observationRevision == revisionAfterCancel)
    }

    @Test("resolve uses conversation verbosity when a conversation is selected")
    func viewModelReadsConversationVerbosityWhenSelected() {
        let id = UUID()
        let capability = FakeVerbosityCapability(
            selectedConversationID: id,
            global: .brief,
            conversation: .detailed
        )
        let viewModel = VerbosityViewModel(capability: capability)

        #expect(viewModel.selectedVerbosity == .detailed)
    }

    @Test("resolve falls back to global verbosity when no conversation is selected")
    func viewModelReadsGlobalVerbosityWhenNoneSelected() {
        let capability = FakeVerbosityCapability(
            selectedConversationID: nil,
            global: .detailed,
            conversation: .brief
        )
        let viewModel = VerbosityViewModel(capability: capability)

        #expect(viewModel.selectedVerbosity == .detailed)
    }

    @Test("select without a conversation updates global verbosity")
    func selectWithoutConversationUpdatesGlobal() {
        let capability = FakeVerbosityCapability(
            selectedConversationID: nil,
            global: .brief,
            conversation: .brief
        )
        let viewModel = VerbosityViewModel(capability: capability)

        viewModel.select(.detailed)

        #expect(capability.globalSet == [.detailed])
        #expect(capability.awaitedSets.isEmpty)
    }

    @Test("select with a conversation updates that conversation and waits")
    @MainActor
    func selectWithConversationUpdatesConversation() async {
        let id = UUID()
        let capability = FakeVerbosityCapability(
            selectedConversationID: id,
            global: .brief,
            conversation: .brief
        )
        let viewModel = VerbosityViewModel(capability: capability)

        viewModel.select(.detailed)

        // select dispatches an async Task; yield to let it run.
        await Task.yield()
        await Task.yield()

        #expect(capability.awaitedSets.map(\.0) == [.detailed])
        #expect(capability.awaitedSets.map(\.1) == [id])
        #expect(capability.globalSet.isEmpty)
    }

    @Test("refresh re-resolves verbosity and bumps observation revision")
    func refreshBumpsRevisionAndReadsCapability() {
        let capability = FakeVerbosityCapability(
            selectedConversationID: nil,
            global: .brief,
            conversation: .brief
        )
        let viewModel = VerbosityViewModel(capability: capability)
        let before = viewModel.observationRevision

        capability.globalVerbosity = .detailed
        viewModel.refresh()

        #expect(viewModel.selectedVerbosity == .detailed)
        #expect(viewModel.observationRevision == before + 1)
    }

    /// 回归 #920：弹层选项名称与说明、chip tooltip 必须经过插件本地化解析，
    /// 而不是读取 `ResponseVerbosity` 里写死的中文字面量。
    ///
    /// 用注入的替身解析器断言「文案确实来自解析器」，因为真实解析结果取决于
    /// 宿主首选语言，无法在 CI 上给出与语言无关的期望值。
    @Test("详细度名称与说明经过注入的本地化解析（回归 #920）")
    func verbosityTextUsesInjectedLocalization() {
        let cases: [(ResponseVerbosity, String, String)] = [
            (.brief, "Brief", "Brief Description"),
            (.standard, "Standard", "Standard Description"),
            (.detailed, "Detailed", "Detailed Description"),
        ]
        let resolve: (String) -> String = { "localized:\($0)" }

        for (level, nameKey, descriptionKey) in cases {
            #expect(
                level.localizedDisplayName(resolve: resolve) == "localized:\(nameKey)",
                "详细度名称未经过本地化解析：\(level.rawValue)"
            )
            #expect(
                level.localizedDescription(resolve: resolve) == "localized:\(descriptionKey)",
                "详细度说明未经过本地化解析：\(level.rawValue)"
            )
        }
    }

    /// 回归 #920：名称与说明词条必须在编译产物里对每种受支持语言都有译文，
    /// 否则英文界面会显示中文，或中文界面回落成英文 key。
    @Test("详细度词条在所有规范语言下都有译文（回归 #920）")
    func verbosityStringsHaveTranslationsInCompiledBundle() throws {
        let expected: [String: [String: String]] = [
            "Brief": [
                "en": "Brief", "zh-Hans": "简洁", "zh-Hant": "簡潔",
                "zh-HK": "簡潔", "zh-TW": "簡潔",
            ],
            "Standard": [
                "en": "Standard", "zh-Hans": "标准", "zh-Hant": "標準",
                "zh-HK": "標準", "zh-TW": "標準",
            ],
            "Detailed": [
                "en": "Detailed", "zh-Hans": "详细", "zh-Hant": "詳細",
                "zh-HK": "詳細", "zh-TW": "詳細",
            ],
            "Brief Description": [
                "en": "Returns only the core conclusion",
                "zh-Hans": "只返回核心结论",
                "zh-Hant": "只回傳核心結論",
                "zh-HK": "只回傳核心結論",
                "zh-TW": "只回傳核心結論",
            ],
            "Standard Description": [
                "en": "Includes essential explanations and steps",
                "zh-Hans": "包含必要说明和步骤",
                "zh-Hant": "包含必要說明和步驟",
                "zh-HK": "包含必要說明和步驟",
                "zh-TW": "包含必要說明和步驟",
            ],
            "Detailed Description": [
                "en": "Includes full reasoning and context",
                "zh-Hans": "包含完整推理和上下文",
                "zh-Hant": "包含完整推理與上下文",
                "zh-HK": "包含完整推理與上下文",
                "zh-TW": "包含完整推理與上下文",
            ],
        ]

        for (key, translations) in expected {
            for (language, translation) in translations {
                let table = try Self.compiledStrings(language: language)
                #expect(
                    table[key] == translation,
                    "\(language) 下 \(key) 译文缺失或不符，详细度控件会回退到其它语言"
                )
            }
        }
    }

    private static func compiledStrings(language: String) throws -> [String: String] {
        let bundle = pluginLocalization.bundle
        let lprojPath = try #require(bundle.path(forResource: language, ofType: "lproj"))
        let stringsPath = (lprojPath as NSString).appendingPathComponent("Localizable.strings")
        return try #require(NSDictionary(contentsOfFile: stringsPath) as? [String: String])
    }

    /// 回归 #1069：缓存在选中后才水合的会话依靠 `.verbosityChanged` 纠正 UI，
    /// 观察者必须对该事件重新求值。
    @Test("Observer 收到 verbosityChanged 后刷新选中详细度")
    func observerRefreshesOnVerbosityChanged() throws {
        let conversations = DefaultConversationManager()
        let adapter = ConversationVerbosityCapabilityAdapter(conversations: conversations)
        let viewModel = VerbosityViewModel(capability: adapter)
        let observer = VerbosityObserver(capability: adapter, viewModel: viewModel)

        let id = try conversations.createConversation(
            title: nil,
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        #expect(viewModel.selectedVerbosity == .defaultVerbosity)

        conversations.setVerbosity(.brief, for: id)

        #expect(viewModel.selectedVerbosity == .brief)
        observer.cancel()
    }
}

@MainActor
private final class FakeVerbosityCapability: ConversationVerbosityCapability {
    var selectedConversationID: UUID?
    var globalVerbosity: ResponseVerbosity
    var conversationVerbosity: ResponseVerbosity
    private(set) var globalSet: [ResponseVerbosity] = []
    private(set) var awaitedSets: [(ResponseVerbosity, UUID?)] = []

    init(selectedConversationID: UUID?, global: ResponseVerbosity, conversation: ResponseVerbosity) {
        self.selectedConversationID = selectedConversationID
        self.globalVerbosity = global
        self.conversationVerbosity = conversation
    }

    func verbosity(for conversationID: UUID?) -> ResponseVerbosity { conversationVerbosity }

    func setVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?) {}

    func setVerbosityAndWait(_ verbosity: ResponseVerbosity, for conversationID: UUID?) async {
        awaitedSets.append((verbosity, conversationID))
    }

    func setGlobalVerbosity(_ verbosity: ResponseVerbosity) {
        globalSet.append(verbosity)
    }

    func addConversationObserver(_ callback: @escaping (ConversationEvent) -> Void) -> any ConversationObserverHandle {
        NoopConversationObserverHandle()
    }
}

@MainActor
private final class NoopConversationObserverHandle: ConversationObserverHandle {
    func cancel() {}
}
