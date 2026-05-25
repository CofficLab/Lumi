import Foundation
import HttpKit

/// 消息发送管线中的通用「下一环」。
public typealias OrderedMiddlewareNext<Context> = @MainActor (Context) async -> Void

/// 通用中间件类型擦除。
///
/// Core 可以用 App 专属的 `SendMessageContext` 适配到这里，独立插件 package
/// 则可以继续使用 `LumiCoreKit.SendMessageContext`。
@MainActor
public struct AnyOrderedMiddleware<Context, Response> {
    public let id: String
    public let order: Int

    private let _handle: @MainActor (Context, @escaping OrderedMiddlewareNext<Context>) async -> Void
    private let _handlePost: @MainActor (HTTPRequestMetadata, Response) async -> Void

    public init(
        id: String,
        order: Int,
        handle: @escaping @MainActor (Context, @escaping OrderedMiddlewareNext<Context>) async -> Void,
        handlePost: @escaping @MainActor (HTTPRequestMetadata, Response) async -> Void = { _, _ in }
    ) {
        self.id = id
        self.order = order
        self._handle = handle
        self._handlePost = handlePost
    }

    public func handle(
        ctx: Context,
        next: @escaping OrderedMiddlewareNext<Context>
    ) async {
        await _handle(ctx, next)
    }

    public func handlePost(metadata: HTTPRequestMetadata, response: Response) async {
        await _handlePost(metadata, response)
    }
}

/// 按 `order` 执行的通用中间件管线。
@MainActor
public final class OrderedMiddlewarePipeline<Context, Response> {
    private let middlewares: [AnyOrderedMiddleware<Context, Response>]

    public init(middlewares: [AnyOrderedMiddleware<Context, Response>]) {
        self.middlewares = middlewares.sorted { $0.order < $1.order }
    }

    public func run(
        ctx: Context,
        terminal: @escaping OrderedMiddlewareNext<Context>
    ) async {
        func makeNext(_ index: Int) -> OrderedMiddlewareNext<Context> {
            { @MainActor ctx in
                if index < self.middlewares.count {
                    await self.middlewares[index].handle(
                        ctx: ctx,
                        next: makeNext(index + 1)
                    )
                } else {
                    await terminal(ctx)
                }
            }
        }

        await makeNext(0)(ctx)
    }

    public func runPost(metadata: HTTPRequestMetadata, response: Response) async {
        for middleware in middlewares {
            await middleware.handlePost(metadata: metadata, response: response)
        }
    }
}
