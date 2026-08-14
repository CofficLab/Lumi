import Foundation
import KernelLumi
import Observation

/// 原型设计器的视图模型。
///
/// 维护一份**独立于主聊天**的对话状态，通过 `kernel.llmProvider` 直接发起流式 LLM 请求，
/// 并在每轮回复中提取 `<artifact>` 更新右侧预览。
///
/// 并发策略：`LumiLLMProvider.sendStreaming` 的 `onChunk` 回调是 `@Sendable`，
/// 无法直接写入本 `@MainActor` 对象。这里用一个 `AsyncThrowingStream` 把 chunk 流
/// 桥接出来，在主线程 `for await` 消费——既满足 Swift 6 并发安全，又保留逐字流式效果。
@MainActor
@Observable
final class PrototypeDesignerViewModel {
    // MARK: - 对话状态

    /// 已完成的对话消息（不含当前正在流式生成的那一条）。
    private(set) var messages: [PrototypeMessage] = []

    /// 输入框文本。
    var inputText: String = ""

    /// 是否正在等待/生成回复。
    private(set) var isLoading: Bool = false

    /// 当前正在流式生成的文本（流结束后会被固化为一条 message 并清空）。
    private(set) var streamingText: String = ""

    /// 最近一次提取到的原型产物（驱动右侧预览）。
    private(set) var currentArtifact: PrototypeArtifact?

    /// 预览区当前选中的设备画框。
    var selectedDevice: PrototypeArtifact.Device = .iphone

    /// 是否切换到「查看 HTML 源码」视图（false = 渲染预览）。
    var showsCode: Bool = false

    /// 最近一次错误信息（用于空态提示）。
    private(set) var errorMessage: String?

    // MARK: - 内部

    private let kernel: KernelLumi
    /// 占位会话 ID：本插件不落库，仅为满足 `LumiChatMessage` 类型要求。
    private var conversationID: UUID = UUID()
    private var generationTask: Task<Void, Never>?

    init(kernel: KernelLumi) {
        self.kernel = kernel
    }

    // MARK: - 输入

    /// 是否可以发送（有文本且未在生成中）。
    var canSend: Bool {
        !isLoading && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 发送当前输入框内容。
    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        inputText = ""
        errorMessage = nil
        messages.append(PrototypeMessage(role: .user, content: text))

        generationTask = Task { [weak self] in
            await self?.runGeneration()
        }
    }

    /// 取消当前生成；已生成部分会作为一条 assistant 消息保留。
    func cancel() {
        generationTask?.cancel()
        generationTask = nil
    }

    /// 清空整段对话与当前产物。
    func clearConversation() {
        generationTask?.cancel()
        generationTask = nil
        messages.removeAll()
        streamingText = ""
        currentArtifact = nil
        errorMessage = nil
        conversationID = UUID()
    }

    /// 把一段模板文本填入输入框。
    func applyTemplate(_ text: String) {
        inputText = text
    }

    // MARK: - 生成

    private func runGeneration() async {
        isLoading = true
        streamingText = ""
        defer { isLoading = false }

        guard let provider = resolveProvider() else {
            let message = "未检测到可用的 LLM Provider。请在设置中配置并启用至少一个模型供应商。"
            errorMessage = message
            messages.append(PrototypeMessage(role: .assistant, content: message, isError: true))
            return
        }
        guard let request = buildRequest(provider: provider) else { return }

        // 把 @Sendable 的 onChunk 桥接成主线程可消费的异步流。
        let stream = AsyncThrowingStream<String, Error> { continuation in
            Task.detached {
                do {
                    _ = try await provider.sendStreaming(request) { chunk in
                        if let piece = chunk.content {
                            continuation.yield(piece)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }

        do {
            for try await piece in stream {
                streamingText += piece
            }
            // 流结束：固化消息并提取最新产物。
            let final = streamingText
            messages.append(PrototypeMessage(role: .assistant, content: final))
            streamingText = ""
            if let artifact = ArtifactExtractor.extract(from: final) {
                currentArtifact = artifact
                selectedDevice = artifact.device
            }
        } catch is CancellationError {
            // 取消：保留已生成的部分文本。
            if !streamingText.isEmpty {
                messages.append(PrototypeMessage(role: .assistant, content: streamingText))
            }
            streamingText = ""
        } catch {
            let message = error.localizedDescription
            errorMessage = message
            messages.append(PrototypeMessage(role: .assistant, content: "⚠️ \(message)", isError: true))
            streamingText = ""
        }
    }

    /// 解析当前应使用的 LLM Provider：优先全局选中，否则取第一个已注册。
    private func resolveProvider() -> (any LumiLLMProvider)? {
        guard let manager = kernel.llmProvider else { return nil }
        if let id = manager.selectedProviderID, let provider = manager.llmProvider(id: id) {
            return provider
        }
        return manager.allLLMProviders().first
    }

    /// 基于本地对话历史与系统提示词构造请求。
    private func buildRequest(provider: any LumiLLMProvider) -> LumiLLMRequest? {
        guard let manager = kernel.llmProvider else { return nil }
        let model = manager.selectedModel ?? type(of: provider).info.defaultModel
        let lumiMessages = PrototypePromptBuilder.buildMessages(
            from: messages,
            conversationID: conversationID,
            device: selectedDevice
        )
        return LumiLLMRequest(messages: lumiMessages, model: model)
    }
}
