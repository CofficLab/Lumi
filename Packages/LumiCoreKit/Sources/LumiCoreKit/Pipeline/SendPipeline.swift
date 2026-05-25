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

    public init<M: SuperSendMiddleware>(_ middleware: M) {
        self.id = middleware.id
        self.order = middleware.order
        self._handle = { ctx, next in
            await middleware.handle(ctx: ctx, next: next)
        }
        self._handlePost = { metadata, response in
            await middleware.handlePost(metadata: metadata, response: response)
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
}

/// 消息发送管线
///
/// 管理中间件的执行，分为两个阶段：
/// 1. **发送前管线**: 通过 `run()` 执行，修改请求
/// 2. **发送后管线**: 通过 `runPost()` 执行，处理响应
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
                    }
                )
            }
        )
    }

    /// 运行发送前管线
    public func run(ctx: SendMessageContext, terminal: @escaping SendPipelineNext) async {
        await pipeline.run(ctx: ctx, terminal: terminal)
    }

    /// 运行发送后管线
    public func runPost(metadata: HTTPRequestMetadata, response: ChatMessage?) async {
        await pipeline.runPost(metadata: metadata, response: response)
    }
}
