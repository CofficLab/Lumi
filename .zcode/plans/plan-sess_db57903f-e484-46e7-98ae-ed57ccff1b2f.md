## 目标

把 `MockMessageSendManager.sendMessage` 的发送链路从"只落 user 消息"扩展为"落 user 消息 → 通过 kernel LLM provider 调用 LLM → 落回 assistant 消息"。协议层加一个 `sendToFirstProvider(_:)` 入口;没有 provider 时抛 `LumiKernelError.llmProviderUnavailable`。

## 改动清单(5 个文件)

### 1. `Packages/LumiKernel/Sources/LumiKernel/Providers/LLMProviderProviding.swift` — 协议扩展

加一个方法:
```swift
/// 发送一条请求到「第一个可用」的 LLM provider
///
/// - Parameter request: LLM 请求
/// - Returns: 完整 assistant 消息
/// - Throws: `LumiKernelError.llmProviderUnavailable` 没有可用 provider 时
func sendToFirstProvider(_ request: LumiLLMRequest) async throws -> LumiChatMessage
```

文件顶部加 `import LumiCoreMessage`(协议要用 `LumiChatMessage`)和 `import LumiCoreLLMProvider`(协议签名要 `LumiLLMRequest`)。

### 2. `Packages/LumiKernel/Sources/LumiKernel/Errors/LumiKernelError.swift` — 错误用例

加一个:
```swift
case llmProviderUnavailable
```

`errorDescription` 加 `"No LLM provider is registered with the kernel"`。

### 3. `Plugins/LLMProviderManagerPlugin/Sources/LLMProviderManagerPlugin/Managers/LLMProviderManager.swift` — 实现

加:
```swift
public func sendToFirstProvider(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
    guard let provider = allLLMProviders().first else {
        if Self.verbose {
            Self.logger.error("\(Self.t)sendToFirstProvider ➡️ 没有可用的 LLM provider, 抛 llmProviderUnavailable")
        }
        throw LumiKernelError.llmProviderUnavailable
    }
    if Self.verbose {
        Self.logger.info("\(Self.t)sendToFirstProvider ➡️ 选 provider id=\(type(of: provider).info.id), model=\(request.model), messages=\(request.messages.count)")
    }
    return try await provider.send(request)
}
```

### 4. `Plugins/MessageSendManagerPlugin/Package.swift` — 加依赖

- `.dependencies` 加 `.package(path: "../../Packages/LumiCoreLLMProvider")`
- `.targets` 加 `.product(name: "LumiCoreLLMProvider", package: "LumiCoreLLMProvider")`

### 5. `Plugins/MessageSendManagerPlugin/Sources/MessageSendManagerPlugin/Managers/MockMessageSendManager.swift` — 接 LLM

- `import LumiCoreLLMProvider`
- `sendMessage` 在 `insertMessage(userMessage, ...)` 之后(在 `isSending = true` / `defer` 块内,但在 `defer` 自动执行前):
  1. 取历史:`let history = kernel?.messageManager?.messages(for: targetID) ?? []`
  2. 解析首个 provider:`guard let provider = kernel?.llmProvider?.allLLMProviders().first else { throw LumiKernelError.llmProviderUnavailable }` — 但更干净是直接 `try await kernel?.llmProvider?.sendToFirstProvider(request)`,把 `nil` 透传(协议不会 nil,这里只是为了不强制解)
  3. 读 `let model = type(of: provider).info.defaultModel`(注意:`provider` 是 `any LumiLLMProvider`;`type(of: provider).info` 取 static)
  4. 构造 `LumiLLMRequest(messages: history, model: model, tools: [])`
  5. `let assistantMessage = try await kernel.llmProvider?.sendToFirstProvider(request) ?? <fallback>` — 但 `sendToFirstProvider` 会抛,无 provider 时抛 `llmProviderUnavailable`,我们让 kernel 的 `?` 透传就好
  6. `kernel?.messageManager?.insertMessage(assistantMessage, to: targetID)`
- 改 `isSending` 时机:把 `defer { isSending = false }` 保留(成功 / 失败都 false);LLM 调用前后打 info 日志:开始 → provider id/model/messages count → 完成 → 落库 assistant 消息
- 错误:`sendToFirstProvider` 抛 `llmProviderUnavailable` 时,捕获后 insertMessage 一条 `.error` 消息 + 重新抛出(由 view 端 `try?` 吞);或直接重新抛出(让 view 端日志显示)— **选择后者**,view 端 `try?` 已经在处理,统一行为

注意 `kernel?.llmProvider?.sendToFirstProvider(request)` 这种链式调用中,如果 `kernel` 是 `nil`,整个表达式返回 `nil` — 不会抛错。我们的 `kernel` 是 `weak`,理论上 init 后不会变 nil,但严谨起见,`guard let kernel else { return }` 放在 sendMessage 入口最简单。

## 范围之外(明确不做)

- 不动 `MessageListView` 的实时刷新(已知问题,本轮不解决)
- 不引入流式:`sendToFirstProvider` 是单次同步 send,Mock provider 内部仍走 streaming 模拟,只是 `send()` 内部 `await sendStreaming { _ in }`,真实发完才返回
- 不写单元测试(仓库内无此 pattern,本轮跳过)
- 不动 `ChatService` / `LumiCoreChat` / `LumiChatServicing`
- 不动 `LLMProviderProviding` 的 `ObservableObject` 化(留待以后,如果要让 MessageList 响应 provider 变化)

## 验证

1. `xcodebuild -scheme LLMProviderManagerPlugin build` 通过
2. `xcodebuild -scheme MessageSendManagerPlugin build` 通过
3. `xcodebuild -scheme Lumi build` 通过
4. 启动 App,在 ConversationInputView 输入文本回车 → 日志应看到:
   - `MockMessageSendManager` 的 "user 消息已落库"
   - `LLMProviderManager.sendToFirstProvider` 选 `mock`
   - `MockLLMProvider.sendStreaming` 开始
   - `MockMessageSendManager` 落库 assistant 消息"(mock) ... [mock]"
5. 边界:在 ChatServiceProviding 还没注册时(理论上不可能 — startup 必填),不应崩

## 提交

单 commit:
```
feat(LLMProvider): add sendToFirstProvider and wire MockMessageSendManager through it

- LLMProviderProviding: add sendToFirstProvider(_:) that delegates to
  the first registered LumiLLMProvider; throws
  LumiKernelError.llmProviderUnavailable when none is registered.
- LumiKernelError: add .llmProviderUnavailable.
- LLMProviderManager: implement sendToFirstProvider, logging the
  chosen provider id and the request shape.
- MessageSendManagerPlugin: add LumiCoreLLMProvider dependency; in
  MockMessageSendManager.sendMessage, after persisting the user
  message, build an LumiLLMRequest from the conversation history
  (using the first provider's defaultModel) and call
  kernel.llmProvider?.sendToFirstProvider. Insert the returned
  assistant message via kernel.messageManager.insertMessage.
```