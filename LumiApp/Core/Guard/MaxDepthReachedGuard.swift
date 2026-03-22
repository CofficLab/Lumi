import Foundation

/// `maxDepth` 相关的深度保护策略：
/// - 当 `depth > maxDepth`：判定为越界，需要触发 `.maxDepthReached`
/// - 当 `depth <= maxDepth`：允许继续执行
struct MaxDepthReachedGuard {
    enum Result {
        case proceed(isFinalStep: Bool)
        case reached(currentDepth: Int, maxDepth: Int)
    }

    func evaluate(depth: Int, maxDepth: Int) -> Result {
        guard depth <= maxDepth else {
            return .reached(currentDepth: depth, maxDepth: maxDepth)
        }
        return .proceed(isFinalStep: depth == maxDepth)
    }
}

