import Foundation
import HttpKit
import LumiCoreKit

/// 消息发送管线中的「下一环」。
typealias SendPipelineNext = @MainActor (SendMessageContext) async -> Void

/// 类型擦除：便于插件返回不同具体类型的中间件实例集合。
@MainActor
struct AnySuperSendMiddleware: SuperSendMiddleware {
    let id: String
    let order: Int
    
    private let _handle: @MainActor (SendMessageContext, @escaping @MainActor (SendMessageContext) async -> Void) async -> Void
    private let _handlePost: @MainActor (HTTPRequestMetadata, ChatMessage?) async -> Void
    private let _handleTurnFinished: @MainActor (TurnFinishedContext) async -> Void

    init<M: SuperSendMiddleware>(_ middleware: M) {
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

    init(_ middleware: LumiCoreKit.AnySuperSendMiddleware) {
        self.id = middleware.id
        self.order = middleware.order
        self._handle = { ctx, next in
            await middleware.handle(ctx: ctx) { coreContext in
                guard let appContext = coreContext as? SendMessageContext else { return }
                await next(appContext)
            }
        }
        self._handlePost = { metadata, response in
            await middleware.handlePost(metadata: metadata, response: response)
        }
        self._handleTurnFinished = { ctx in
            await middleware.handleTurnFinished(ctx: ctx)
        }
    }

    func handle(
        ctx: SendMessageContext,
        next: @escaping @MainActor (SendMessageContext) async -> Void
    ) async {
        await _handle(ctx, next)
    }
    
    func handlePost(
        metadata: HTTPRequestMetadata,
        response: ChatMessage?
    ) async {
        await _handlePost(metadata, response)
    }

    func handleTurnFinished(
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
final class SendPipeline {
    private let pipeline: LumiCoreKit.OrderedMiddlewarePipeline<SendMessageContext, ChatMessage?>

    init(middlewares: [SuperSendMiddleware]) {
        self.pipeline = LumiCoreKit.OrderedMiddlewarePipeline(
            middlewares: middlewares.map { middleware in
                LumiCoreKit.AnyOrderedMiddleware(
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
    ///
    /// - Parameters:
    ///   - ctx: 发送上下文
    ///   - terminal: 管线结束时的回调
    func run(ctx: SendMessageContext, terminal: @escaping SendPipelineNext) async {
        await pipeline.run(ctx: ctx, terminal: terminal)
    }
    
    /// 运行每次请求后管线
    ///
    /// 在单次 LLM 响应后调用，按 order 顺序执行所有中间件的 `handlePost` 方法。
    ///
    /// - Parameters:
    ///   - metadata: 请求元数据
    ///   - response: LLM 响应消息（如果失败则为 nil）
    func runPost(metadata: HTTPRequestMetadata, response: ChatMessage?) async {
        await pipeline.runPost(metadata: metadata, response: response)
    }

    /// 运行 Turn 结束后管线
    ///
    /// 在 AgentTurnService 的 Turn 收尾方法中调用，
    /// 按 order 顺序执行所有中间件的 `handleTurnFinished` 方法。
    ///
    /// - Parameter ctx: Turn 结束上下文
    func runTurnFinished(ctx: TurnFinishedContext) async {
        await pipeline.runTurnFinished(ctx: ctx)
    }
}
