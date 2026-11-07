import Foundation
import os

/// 协作式取消令牌。
///
/// 长耗时的 libgit2 操作（clone / fetch / push / diff / revwalk / blame）会在
/// 回调或循环中周期性地检查该令牌，从而实现"中途取消"。
///
/// 设计上刻意保持为**同步、可跨线程**的轻量对象：libgit2 的 C 回调是同步
/// 调用且不允许抛出 Swift 错误，因此回调只能通过读取 `isCancelled` 返回非 0
/// 值来中止操作，由调用方在操作返回后检查并抛出 `CancellationError`。
public final class GitCancellationToken: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: false)

    public init() {}

    /// 请求取消。幂等，可从任意线程调用。
    public func cancel() {
        lock.withLock { $0 = true }
    }

    /// 是否已被请求取消。
    public var isCancelled: Bool {
        lock.withLock { $0 }
    }

    /// 若已请求取消则抛出 `CancellationError`。
    ///
    /// 用于在操作的入口、出口以及耗时循环的检查点调用。
    public func checkCancellation() throws {
        if isCancelled {
            throw CancellationError()
        }
    }

    /// 供 libgit2 的 C 回调使用的闭包形式。
    ///
    /// 回调约定返回非 0 值表示中止操作。令牌未被取消时返回 `false`（0）。
    public var shouldCancel: @Sendable () -> Bool {
        { [self] in isCancelled }
    }

    /// 基于异步 `Task` 的取消状态自动联动的令牌。
    ///
    /// 当 `task.isCancelled` 变为 true 时令牌随即生效，便于 UI 层把 Swift
    /// 结构化并发取消直接传导到同步的 libgit2 调用。
    public static func observing(_ task: Task<Void, Never>) -> GitCancellationToken {
        let token = GitCancellationToken()
        Task.detached(priority: .high) {
            while !Task.isCancelled {
                if task.isCancelled {
                    token.cancel()
                    return
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        return token
    }
}

/// 取消令牌为空时的兼容入口。
///
/// 库内所有可取消 API 都接受 `cancellation: GitCancellationToken? = nil`，
/// 通过该辅助方法统一"无令牌"语义，避免每个实现点重复解包。
@inline(__always)
func checkCancellation(_ token: GitCancellationToken?) throws {
    try token?.checkCancellation()
}

@inline(__always)
func isCancelled(_ token: GitCancellationToken?) -> Bool {
    token?.isCancelled ?? false
}
