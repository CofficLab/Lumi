import Foundation
import Testing
import KernelLumi
@testable import LLMProviderDeepSeekPlugin

@MainActor
struct PluginLLMProviderDeepSeekTests {
    @Test func pluginMetadata() {
        let plugin = DeepSeekPlugin()
        #expect(plugin.id.isEmpty == false)
        #expect(plugin.name.isEmpty == false)
        #expect(plugin.category == .llmProvider)
        #expect(plugin.llmProviders(kernel: KernelLumi()).first is DeepSeekOpenAIProvider)
    }

    @Test func providerMetadata() {
        #expect(DeepSeekOpenAIProvider.info.id.isEmpty == false)
        #expect(DeepSeekOpenAIProvider.info.displayName.isEmpty == false)
        #expect(DeepSeekOpenAIProvider.info.defaultModel.isEmpty == false)
    }

    @Test func parsesDeepSeekCacheUsage() {
        let events = DeepSeekEventParser.parse(Data(
            #"data: {"usage":{"prompt_cache_hit_tokens":30,"prompt_cache_miss_tokens":12,"completion_tokens":11}}"#.utf8
        ))

        #expect(events.count == 1)
        #expect(events[0].cacheHitTokens == 30)
        #expect(events[0].cacheTotalInputTokens == 42)
        #expect(events[0].outputTokens == 11)
    }

    @Test func anthropicUsageTotalIncludesCacheRead() {
        // 实测(2026-08-06):DeepSeek Anthropic 端点的 input_tokens 是「未命中」部分,
        // 缓存率分母必须 = input_tokens + cache_read_input_tokens。
        // 例:总输入 580 = input_tokens(68) + cache_read(512)。
        let conversation = UUID()
        var message = DeepSeekChatMessage.assembling(
            conversationID: conversation,
            providerID: "deepseek-anthropic",
            modelName: "deepseek-v4-flash"
        )
        message.mergeUsage(DeepSeekAnthropicUsage(
            inputTokens: 68,
            outputTokens: 14,
            cacheReadInputTokens: 512,
            cacheCreationInputTokens: 0
        ))
        #expect(message.inputTokenCount == 68)
        #expect(message.cachedInputTokens == 512)
        #expect(message.cacheTotalInputTokens == 580)
    }

    // MARK: - max_tokens 截断判定(hitMaxTokensWithoutOutput)

    private func makeMessage() -> DeepSeekChatMessage {
        DeepSeekChatMessage.assembling(
            conversationID: UUID(),
            providerID: "deepseek-anthropic",
            modelName: "deepseek-v4-flash"
        )
    }

    @Test("max_tokens + 无任何可见输出 → 判定命中(Anthropic 命名)")
    func maxTokensWithoutOutputAnthropicNaming() {
        var message = makeMessage()
        message.setStopReason("max_tokens")
        #expect(message.hitMaxTokensWithoutOutput)
    }

    @Test("length + 无任何可见输出 → 判定命中(OpenAI 端点 finish_reason 命名)")
    func maxTokensWithoutOutputOpenAINaming() {
        var message = makeMessage()
        message.setStopReason("length")
        #expect(message.hitMaxTokensWithoutOutput)
    }

    @Test("max_tokens 但已有部分文本 → 不判定(保留部分输出)")
    func maxTokensWithPartialText() {
        var message = makeMessage()
        message.setStopReason("max_tokens")
        message.mergeTextDelta("partial answer", now: Date())
        #expect(message.hitMaxTokensWithoutOutput == false)
    }

    @Test("max_tokens 但已有工具调用 → 不判定")
    func maxTokensWithToolCall() {
        var message = makeMessage()
        message.setStopReason("max_tokens")
        message.beginToolCall(id: "call_01", name: "search")
        #expect(message.hitMaxTokensWithoutOutput == false)
    }

    @Test("正常结束(end_turn)即使无输出也不判定")
    func normalStopNotTruncated() {
        var message = makeMessage()
        message.setStopReason("end_turn")
        #expect(message.hitMaxTokensWithoutOutput == false)
    }

    @Test("maxTokensExceeded 错误文案与重试策略")
    func maxTokensExceededErrorMetadata() {
        let error = AnthropicProviderError.maxTokensExceeded(4096)
        #expect(error.errorDescription?.contains("max_tokens") == true)
        #expect(error.errorDescription?.contains("4096") == true)
        #expect(error.llmErrorDisposition.isRetryable == false)

        let openAIError = DeepSeekOpenAIProviderError.maxTokensExceeded(nil)
        #expect(openAIError.errorDescription?.contains("max_tokens") == true)
        #expect(openAIError.llmErrorDisposition.isRetryable == false)
    }
}

@Suite("SSESequenceAccumulator")
struct SSESequenceAccumulatorTests {
    /// 构造 N 个 SSE 帧文本
    private func makeStream() -> String {
        [
            "event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"usage\":{\"input_tokens\":91,\"cache_read_input_tokens\":42112}}}",
            "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"\(String(repeating: "A", count: 20000))\"}}",
            "event: message_delta\ndata: {\"type\":\"message_delta\",\"usage\":{\"output_tokens\":8,\"cache_read_input_tokens\":42112}}",
            "event: message_stop\ndata: {\"type\":\"message_stop\"}",
        ].joined(separator: "\n\n") + "\n\n"
    }

    @Test("跨 chunk 的大帧也能完整累积解析(修复 16KB 分块丢帧)")
    func largeFrameAcrossChunks() {
        let full = Data(makeStream().utf8)
        let chunks = stride(from: 0, to: full.count, by: 16384).map { i in
            full.subdata(in: i..<min(i + 16384, full.count))
        }
        #expect(chunks.count > 1, "测试流应跨多个 16KB chunk")

        let accumulator = SSESequenceAccumulator()
        var frames: [Data] = []
        for chunk in chunks {
            frames += accumulator.appendAndDrain(chunk)
        }
        if let remaining = accumulator.drainRemaining() {
            frames.append(remaining)
        }

        // 期望 4 个完整帧(不丢事件)
        #expect(frames.count == 4, "应为 4 帧,实际 \(frames.count)")
        var parsedFrames: [(String, String)] = []
        for frame in frames {
            let text = String(decoding: frame, as: UTF8.self)
            var eventType: String?
            var payload: String?
            for line in text.split(separator: "\n") {
                let line = String(line)
                if line.hasPrefix("event:") {
                    eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                }
            }
            if let eventType, let payload {
                parsedFrames.append((eventType, payload))
            }
        }
        let types = parsedFrames.map(\.0)
        #expect(types == ["message_start", "content_block_delta", "message_delta", "message_stop"],
                "事件类型应完整,实际 \(types)")
        // 大帧的 payload 完整(含全部 20000 个 A)
        let big = parsedFrames.first { $0.0 == "content_block_delta" }?.1 ?? ""
        #expect(big.contains(String(repeating: "A", count: 20000)))
    }

    @Test("CRLF 分隔符也能切分")
    func crlfSeparator() {
        let stream = Data("event: message_start\ndata: {\"a\":1}\r\n\r\nevent: message_delta\ndata: {\"b\":2}\r\n\r\n".utf8)
        let accumulator = SSESequenceAccumulator()
        let frames = accumulator.appendAndDrain(stream)
        #expect(frames.count == 2)
    }

    @Test("单个 chunk 内多个完整帧 + 尾部残帧留待下块")
    func multipleFramesAndPartialTail() {
        let accumulator = SSESequenceAccumulator()
        let block1 = Data("event: a\ndata: {}\n\nevent: b\ndata: {}\n\nevent: c\ndata: {\"partial\":".utf8)
        let frames1 = accumulator.appendAndDrain(block1)
        #expect(frames1.count == 2, "前两个完整帧应被切出")
        let block2 = Data("true}\n\n".utf8)
        let frames2 = accumulator.appendAndDrain(block2)
        #expect(frames2.count == 1, "残缺帧补齐后应切出")
        // 流结束无残余
        #expect(accumulator.drainRemaining() == nil)
    }
}
