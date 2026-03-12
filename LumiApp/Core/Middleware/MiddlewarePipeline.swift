import Foundation

/// 一个简单的、按顺序执行的事件中间件管线。
///
/// - 中间件可以修改共享的 `Context`（引用类型），并决定是否调用 `next`。
/// - `terminal` 表示链尾默认处理逻辑（当没有中间件短路时执行）。
@MainActor
final class MiddlewarePipeline<Event, Context: AnyObject> {
    typealias Next = @MainActor (Event, Context) async -> Void
    typealias Middleware = @MainActor (_ event: Event, _ ctx: Context, _ next: @escaping Next) async -> Void

    private let middlewares: [Middleware]

    init(middlewares: [Middleware]) {
        self.middlewares = middlewares
    }

    func run(_ event: Event, ctx: Context, terminal: @escaping Next) async {
        func makeNext(_ index: Int) -> Next {
            { @MainActor event, ctx in
                if index < self.middlewares.count {
                    await self.middlewares[index](event, ctx, makeNext(index + 1))
                } else {
                    await terminal(event, ctx)
                }
            }
        }

        await makeNext(0)(event, ctx)
    }
}

