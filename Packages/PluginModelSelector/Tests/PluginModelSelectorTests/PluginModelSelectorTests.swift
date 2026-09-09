import Testing
import Foundation
import KernelCore
import ProviderConversation
import ProviderLLMManager
import KitLLM
@testable import PluginModelSelector

@Suite("Model category")
struct ModelCategoryTests {
    @Test("Classifies language, vision and tool models via metadata")
    func classifiesViaMetadata() {
        let language = LLMModelInfo(id: "qwen3-max", supportsVision: false, supportsTools: false)
        let vision = LLMModelInfo(id: "gpt-5.5", supportsVision: true, supportsTools: true)
        let visionOnly = LLMModelInfo(id: "qwen-vl-plus", supportsVision: true, supportsTools: false)

        #expect(ModelCategory.language.includes(model: language.id, modelInfo: language))
        #expect(!ModelCategory.vision.includes(model: language.id, modelInfo: language))
        #expect(ModelCategory.vision.includes(model: vision.id, modelInfo: vision))
        #expect(ModelCategory.vision.includes(model: visionOnly.id, modelInfo: visionOnly))
        #expect(ModelCategory.tools.includes(model: vision.id, modelInfo: vision))
        #expect(!ModelCategory.tools.includes(model: visionOnly.id, modelInfo: visionOnly))
        #expect(ModelCategory.all.includes(model: language.id, modelInfo: language))
    }

    @Test("Classifies audio and image models via id heuristics")
    func classifiesViaHeuristics() {
        let tts = LLMModelInfo(id: "mimo-v2.5-tts", supportsVision: false, supportsTools: false)
        let asr = LLMModelInfo(id: "stepaudio-2.5-asr", supportsVision: false, supportsTools: false)
        let image = LLMModelInfo(id: "qwen-image-2.0", supportsVision: true, supportsTools: false)
        let chat = LLMModelInfo(id: "deepseek-chat", supportsVision: false, supportsTools: true)

        #expect(ModelCategory.audio.includes(model: tts.id, modelInfo: tts))
        #expect(ModelCategory.audio.includes(model: asr.id, modelInfo: asr))
        #expect(!ModelCategory.audio.includes(model: chat.id, modelInfo: chat))

        #expect(ModelCategory.image.includes(model: image.id, modelInfo: image))
        #expect(!ModelCategory.image.includes(model: chat.id, modelInfo: chat))

        // 图像/语音类不应落入「语言模型」或「视觉模型」
        #expect(!ModelCategory.language.includes(model: tts.id, modelInfo: tts))
        #expect(!ModelCategory.language.includes(model: image.id, modelInfo: image))
        #expect(!ModelCategory.vision.includes(model: image.id, modelInfo: image))
    }

    @Test("Missing metadata falls back to id-only classification")
    func missingMetadataFallsBackToLanguage() {
        #expect(ModelCategory.language.includes(model: "unknown-model", modelInfo: nil))
        #expect(ModelCategory.all.includes(model: "unknown-model", modelInfo: nil))
        #expect(!ModelCategory.vision.includes(model: "unknown-model", modelInfo: nil))
        #expect(!ModelCategory.tools.includes(model: "unknown-model", modelInfo: nil))
        #expect(ModelCategory.audio.includes(model: "some-tts-model", modelInfo: nil))
    }
}

@Suite("Provider scope")
struct ProviderScopeTests {
    @Test("Cloud and local scopes use provider metadata")
    func filtersUsingIsLocal() {
        let cloudProvider = makeProvider(id: "cloud", isLocal: false)
        let localProvider = makeProvider(id: "local", isLocal: true)

        #expect(ProviderScope.cloud.includes(cloudProvider))
        #expect(!ProviderScope.cloud.includes(localProvider))
        #expect(ProviderScope.local.includes(localProvider))
        #expect(!ProviderScope.local.includes(cloudProvider))
        #expect(ProviderScope.frequent.includes(cloudProvider, usageCount: 1))
        #expect(!ProviderScope.frequent.includes(localProvider))
    }

    private func makeProvider(id: String, isLocal: Bool) -> LLMProviderInfo {
        LLMProviderInfo(
            id: id,
            displayName: id,
            defaultModel: "model",
            models: [],
            isLocal: isLocal
        )
    }
}

@Suite("Provider usage store")
@MainActor
struct ProviderUsageStoreTests {
    @Test("Persists approximate provider usage and ranks by count")
    func persistsAndRanksUsage() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModelSelectorTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let firstDate = Date(timeIntervalSince1970: 1_000)
        let secondDate = Date(timeIntervalSince1970: 2_000)
        let store = ProviderUsageStore(directory: directory)
        store.recordUse(providerID: "openai", at: firstDate)
        store.recordUse(providerID: "deepseek", at: secondDate)
        store.recordUse(providerID: "openai", at: secondDate)

        #expect(store.usageCount(for: "openai") == 2)
        #expect(store.lastUsedAt(for: "openai") == secondDate)
        #expect(store.isMoreFrequentlyUsed("openai", than: "deepseek"))

        let reloadedStore = ProviderUsageStore(directory: directory)
        #expect(reloadedStore.usageCount(for: "openai") == 2)
        #expect(reloadedStore.lastUsedAt(for: "deepseek") == secondDate)
    }
}

@Suite("ModelSelectorPlugin metadata")
@MainActor
struct ModelSelectorPluginMetadataTests {
    @Test("Keeps legacy plugin id, order and policy")
    func identityAndPolicy() {
        let plugin = ModelSelectorPlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.model-selector")
        #expect(plugin.order == 82)
        #expect(plugin.metadata.policy == .alwaysOn)
        #expect(plugin.metadata.category == .core)
    }
}

@Suite("Model selection capability")
@MainActor
struct ModelSelectionCapabilityTests {
    @Test("选中对话时写入对话模型，不覆盖全局模型")
    func selectionWithConversationUpdatesConversation() throws {
        let manager = DefaultLLMManager()
        try manager.register(TestProvider(
            id: "model-selection-conversation-provider",
            models: ["global-model", "conversation-model"]
        ))
        manager.select(
            providerID: "model-selection-conversation-provider",
            model: "global-model"
        )

        let conversations = DefaultConversationManager()
        let conversationID = try conversations.createConversation(
            title: "selection test",
            projectPath: nil,
            providerID: "model-selection-conversation-provider",
            modelName: "global-model"
        )
        conversations.selectConversation(id: conversationID)

        let capability = ModelSelectionCapabilityAdapter(
            conversations: conversations,
            llmManager: manager
        )
        capability.select(
            providerID: "model-selection-conversation-provider",
            model: "conversation-model"
        )

        #expect(conversations.modelName(for: conversationID) == "conversation-model")
        #expect(manager.selectedModel == "global-model")
        #expect(capability.selectedModel == "conversation-model")
    }

    @Test("没有选中对话时写入全局模型")
    func selectionWithoutConversationUpdatesGlobal() throws {
        let manager = DefaultLLMManager()
        try manager.register(TestProvider(
            id: "model-selection-global-provider",
            models: ["global-model", "other-model"]
        ))
        manager.select(
            providerID: "model-selection-global-provider",
            model: "global-model"
        )

        let conversations = DefaultConversationManager()
        let capability = ModelSelectionCapabilityAdapter(
            conversations: conversations,
            llmManager: manager
        )
        capability.select(
            providerID: "model-selection-global-provider",
            model: "other-model"
        )

        #expect(manager.selectedModel == "other-model")
        #expect(capability.selectedModel == "other-model")
    }
}

@Suite("LLM provider manager box")
@MainActor
struct LLMProviderManagerBoxTests {
    @Test("Refreshes its snapshot through typed events")
    func refreshesSnapshotThroughTypedEvents() throws {
        let manager = DefaultLLMManager()
        let box = LLMProviderManagerBox(manager: manager)
        var eventCount = 0
        let handle = box.addObserver { _ in eventCount += 1 }

        try manager.register(TestProvider(
            id: "box-provider",
            models: ["box-model"]
        ))

        #expect(eventCount > 0)
        #expect(box.providerInfo(id: "box-provider")?.id == "box-provider")
        #expect(box.models(for: "box-provider") == ["box-model"])

        handle.cancel()
    }
}

@MainActor
private final class TestProvider: ManagedLLMProvider {
    let providerInfo: LLMProviderInfo

    init(id: String, models: [String]) {
        providerInfo = LLMProviderInfo(
            id: id,
            displayName: id,
            defaultModel: models[0],
            models: models.map { LLMModelInfo(id: $0) }
        )
    }

    var providerID: String { providerInfo.id }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(content: "ok", model: request.model)
    }
}
