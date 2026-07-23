import Foundation

/// Serializes libgit2 access across threads.
///
/// `libgit2` is not thread-safe by default; all access must be funneled through a single
/// queue to avoid concurrent invocations corrupting repository state. This lightweight
/// coordinator provides that shared queue plus a small `performSync { ... }` helper that
/// used to live in this file before being migrated to `GitAsyncBridge`.
enum GitAccessCoordinator {
    /// Single serial queue used for all libgit2 calls in the GitPlugin (and reused by other
    /// plugins that touch libgit2, e.g. `EditorFileTreePlugin` / `EditorFileTreeV2Plugin`).
    static let queue = DispatchQueue(
        label: "com.coffic.lumi.git-access-coordinator",
        qos: .userInitiated
    )

    /// Run `body` synchronously on the shared queue and return its result.
    /// Wraps `DispatchQueue.sync` for ergonomic call sites that still want to inline the
    /// work rather than going through `GitAsyncBridge.perform(on:)` (which is async).
    static func performSync<T>(_ body: () throws -> T) rethrows -> T {
        try queue.sync(execute: body)
    }
}