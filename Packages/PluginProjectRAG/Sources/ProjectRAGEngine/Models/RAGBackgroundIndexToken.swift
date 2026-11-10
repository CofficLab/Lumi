import Foundation

/// 后台索引的取消代次。
///
/// `RAGIndexScheduler` 在派发切片前捕获令牌；即使前台中断发生在索引 child
/// 真正进入 `RAGService` 之前，旧代次令牌也不会重新打开中断（回归 #1117）。
public struct RAGBackgroundIndexToken: Sendable, Equatable {
    let generation: UInt64

    init(generation: UInt64) {
        self.generation = generation
    }
}
