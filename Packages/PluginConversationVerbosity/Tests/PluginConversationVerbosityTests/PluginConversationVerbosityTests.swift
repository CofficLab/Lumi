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
            (.zcode, "ZCode", "ZCode Description"),
            (.chatGPT, "ChatGPT", "ChatGPT Description"),
            (.standardNoHeader, "No Header", "No Header Description"),
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
            "Message List Style": [
                "en": "Message List Style", "zh-Hans": "消息列表风格",
                "zh-Hant": "訊息列表風格", "zh-HK": "訊息列表風格",
                "zh-TW": "訊息列表風格",
            ],
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
                "en": "Groups messages by turn, with a collapsed process section",
                "zh-Hans": "按回合分组消息，过程区段折叠",
                "zh-Hant": "按回合分組訊息，過程區段折疊",
                "zh-HK": "按回合分組訊息，過程區段折疊",
                "zh-TW": "按回合分組訊息，過程區段折疊",
            ],
            "Standard Description": [
                "en": "Lists every message row in a plain layout",
                "zh-Hans": "以朴素布局逐条列出消息",
                "zh-Hant": "以樸素佈局逐條列出訊息",
                "zh-HK": "以樸素佈局逐條列出訊息",
                "zh-TW": "以樸素佈局逐條列出訊息",
            ],
            "Detailed Description": [
                "en": "Lists every message row and shows the reasoning content",
                "zh-Hans": "逐条列出消息，并显示思考内容",
                "zh-Hant": "逐條列出訊息，並顯示思考內容",
                "zh-HK": "逐條列出訊息，並顯示思考內容",
                "zh-TW": "逐條列出訊息，並顯示思考內容",
            ],
            "ZCode": [
                "en": "ZCode", "zh-Hans": "ZCode", "zh-Hant": "ZCode",
                "zh-HK": "ZCode", "zh-TW": "ZCode",
            ],
            "ZCode Description": [
                "en": "ZCode-style message presentation",
                "zh-Hans": "ZCode 风格消息呈现",
                "zh-Hant": "ZCode 風格訊息呈現",
                "zh-HK": "ZCode 風格訊息呈現",
                "zh-TW": "ZCode 風格訊息呈現",
            ],
            "ChatGPT": [
                "en": "ChatGPT", "zh-Hans": "ChatGPT", "zh-Hant": "ChatGPT",
                "zh-HK": "ChatGPT", "zh-TW": "ChatGPT",
            ],
            "ChatGPT Description": [
                "en": "ChatGPT-style message list",
                "zh-Hans": "ChatGPT 风格消息列表",
                "zh-Hant": "ChatGPT 風格訊息列表",
                "zh-HK": "ChatGPT 風格訊息列表",
                "zh-TW": "ChatGPT 風格訊息列表",
            ],
            "No Header": [
                "en": "No Header", "zh-Hans": "无消息头", "zh-Hant": "無訊息頭",
                "zh-HK": "無訊息頭", "zh-TW": "無訊息頭",
            ],
            "No Header Description": [
                "en": "Standard layout without message headers",
                "zh-Hans": "标准布局，不显示消息头",
                "zh-Hant": "標準佈局，不顯示訊息頭",
                "zh-HK": "標準佈局，不顯示訊息頭",
                "zh-TW": "標準佈局，不顯示訊息頭",
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

    /// 回归 #217：快速切换详细度时，旧写入不得覆盖新选择。
    ///
    /// 用门闩构造「旧请求晚到」：先放行新写入、再放行旧写入，
    /// 断言最终落盘的仍是最后一次选择，而不是晚到的旧值。
    @Test("快速切换详细度时旧写入晚到也不能覆盖新选择（回归 #217）")
    func lastSelectionWinsWhenEarlierWriteCompletesLast() async {
        let id = UUID()
        let capability = GatedVerbosityCapability(selectedConversationID: id)
        let viewModel = VerbosityViewModel(capability: capability)

        viewModel.select(.brief)      // 旧选择
        viewModel.select(.detailed)   // 新选择（最终必须生效）
        await settle()

        // 故意先完成新写入、再完成旧写入，模拟旧请求晚到。
        capability.complete(.detailed)
        await settle()
        capability.complete(.brief)
        await settle()
        // 串行化下 .detailed 可能在 .brief 完成后才提交，这里再放行一次。
        capability.complete(.detailed)
        await settle()

        #expect(capability.persisted == .detailed)
    }

    /// 回归 #217：旧写入已经在途时，新选择必须等它结束再落盘，不能被旧写入反超。
    @Test("在途旧写入未结束前新选择不得提前落盘（回归 #217）")
    func inFlightEarlierWriteCannotOverwriteLaterSelection() async {
        let id = UUID()
        let capability = GatedVerbosityCapability(selectedConversationID: id)
        let viewModel = VerbosityViewModel(capability: capability)

        viewModel.select(.brief)
        await settle()   // 让 .brief 写入开始并悬停在门闩上（在途）
        #expect(capability.submitted == [.brief])

        viewModel.select(.detailed)   // .brief 仍在途
        await settle()
        // 串行化：.brief 完成前 .detailed 不得提交。
        #expect(capability.submitted == [.brief])

        capability.complete(.brief)   // 旧写入完成
        await settle()
        #expect(capability.submitted == [.brief, .detailed])

        capability.complete(.detailed)
        await settle()
        #expect(capability.persisted == .detailed)
    }

    /// 让主 actor 上排队的写入任务充分推进（链深最多 2，50 次 yield 足够）。
    private func settle() async {
        for _ in 0..<50 { await Task.yield() }
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

/// 可控门闩替身：`setVerbosityAndWait` 提交后悬停，直到测试显式放行，
/// 用来构造「旧写入晚到」的竞态（回归 #217）。`persisted` 按完成顺序赋值，
/// 模拟落盘写回——最后完成的那次写入决定最终值。
@MainActor
private final class GatedVerbosityCapability: ConversationVerbosityCapability {
    var selectedConversationID: UUID?
    var globalVerbosity: ResponseVerbosity = .standard
    private(set) var persisted: ResponseVerbosity?
    private(set) var submitted: [ResponseVerbosity] = []
    private var gates: [ResponseVerbosity: CheckedContinuation<Void, Never>] = [:]

    init(selectedConversationID: UUID?) {
        self.selectedConversationID = selectedConversationID
    }

    func verbosity(for conversationID: UUID?) -> ResponseVerbosity { persisted ?? .standard }

    func setVerbosity(_ verbosity: ResponseVerbosity, for conversationID: UUID?) {}

    func setVerbosityAndWait(_ verbosity: ResponseVerbosity, for conversationID: UUID?) async {
        submitted.append(verbosity)
        await withCheckedContinuation { continuation in
            gates[verbosity] = continuation
        }
        persisted = verbosity
    }

    func setGlobalVerbosity(_ verbosity: ResponseVerbosity) {
        globalVerbosity = verbosity
    }

    func addConversationObserver(_ callback: @escaping (ConversationEvent) -> Void) -> any ConversationObserverHandle {
        NoopConversationObserverHandle()
    }

    /// 放行指定详细度的在途写入；尚未提交时为空操作。
    func complete(_ verbosity: ResponseVerbosity) {
        gates.removeValue(forKey: verbosity)?.resume()
    }
}
