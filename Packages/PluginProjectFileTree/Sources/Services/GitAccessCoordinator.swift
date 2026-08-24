import Foundation

/// Serializes libgit2 access within this plugin.
///
/// `libgit2` is not thread-safe by default; all access must be funneled through a single
/// queue to avoid concurrent invocations corrupting repository state. This lightweight
/// coordinator provides that shared queue plus a `performSync { ... }` helper.
///
/// 注意:本插件独立维护该队列。若同一进程内其他插件(如 GitPlugin)也访问 libgit2,
/// 它们各自有自己的串行队列;不同仓库的并发访问是安全的,同一仓库内的串行化
/// 由各自的调用方保证。
enum GitAccessCoordinator {
    /// Single serial queue used for all libgit2 calls in this plugin.
    static let queue = DispatchQueue(
        label: "com.coffic.lumi.project-file-tree.git-access-coordinator",
        qos: .userInitiated
    )

    /// Run `body` synchronously on the shared queue and return its result.
    static func performSync<T>(_ body: () throws -> T) rethrows -> T {
        try queue.sync(execute: body)
    }
}
