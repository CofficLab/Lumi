import Foundation
import HttpKit

/// 消息发送管线中的「下一环」。
public typealias SendPipelineNext = @MainActor (SendMessageContext) async -> Void

/// 类型擦除：便于插件返回不同具体类型的中间件实例集合。
@MainActor
public struct AnySuperSendMiddleware: SuperSendMiddleware {
    public let id: String
    public let order: Int

    private let _handle: @MainActor (SendMessageContext, @escaping @MainActor (SendMessageContext) async -> Void) async -> Void
    private let _handlePost: @MainActor (HTTPRequestMetadata, ChatMessage?) async -> Void
    private let _handleTurnFinished: @MainActor (TurnFinishedContext) async -> Void

    public init<M: SuperSendMiddleware>(_ middleware: M) {
        self.id = middleware.id
        self.order = middleware.order
        self._handle = { ctx, next in
            await middleware.handle(ctx: ctx, next: next)
        }
        self._handlePost = { metadata, response in
            await middleware.handlePost(metadata: metadata, response: response)
        }
        self._handleTurnFinished = { ctx in
            await middleware.handleTurnFinished(ctx: ctx)
        }
    }

    public func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        await _handle(ctx, next)
    }

    public func handlePost(
        metadata: HTTPRequestMetadata,
        response: ChatMessage?
    ) async {
        await _handlePost(metadata, response)
    }

    public func handleTurnFinished(
        ctx: TurnFinishedContext
    ) async {
        await _handleTurnFinished(ctx)
    }
}

/// 消息发送管线
///
/// 管理中间件的执行，分为三个阶段：
/// 1. **发送前管线**: 通过 `run()` 执行，修改请求
/// 2. **每次请求后管线**: 通过 `runPost()` 执行，处理单次 LLM 响应
/// 3. **Turn 结束后管线**: 通过 `runTurnFinished()` 执行，在整个 Agent 回合结束后收尾
@MainActor
public final class SendPipeline {
    private let pipeline: OrderedMiddlewarePipeline<SendMessageContext, ChatMessage?>

    public init(middlewares: [SuperSendMiddleware]) {
        self.pipeline = OrderedMiddlewarePipeline(
            middlewares: middlewares.map { middleware in
                AnyOrderedMiddleware(
                    id: middleware.id,
                    order: middleware.order,
                    handle: { ctx, next in
                        await middleware.handle(ctx: ctx, next: next)
                    },
                    handlePost: { metadata, response in
                        await middleware.handlePost(metadata: metadata, response: response)
                    },
                    handleTurnFinished: { ctx in
                        await middleware.handleTurnFinished(ctx: ctx)
                    }
                )
            }
        )
    }

    /// 运行发送前管线
    public func run(ctx: SendMessageContext, terminal: @escaping SendPipelineNext) async {
        await pipeline.run(ctx: ctx, terminal: terminal)
    }

    /// 运行每次请求后管线
    public func runPost(metadata: HTTPRequestMetadata, response: ChatMessage?) async {
        await pipeline.runPost(metadata: metadata, response: response)
    }

    /// 运行 Turn 结束后管线
    ///
    /// 在 `AgentTurnService` 的 Turn 收尾方法中调用，
    /// 按 `order` 顺序执行所有中间件的 `handleTurnFinished` 方法。
    public func runTurnFinished(ctx: TurnFinishedContext) async {
        await pipeline.runTurnFinished(ctx: ctx)
    }
}
