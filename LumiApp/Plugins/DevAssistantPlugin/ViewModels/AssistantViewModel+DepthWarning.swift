import Foundation
import OSLog

// MARK: - 深度警告管理

extension AssistantViewModel {
    // MARK: - 深度警告管理

    /// 更新深度警告状态
    func updateDepthWarning(currentDepth: Int, maxDepth: Int) {
        if currentDepth >= maxDepth - 1 {
            depthWarning = DepthWarning(currentDepth: currentDepth, maxDepth: maxDepth, warningType: .critical)
        } else if currentDepth >= maxDepth * 8 / 10 {
            depthWarning = DepthWarning(currentDepth: currentDepth, maxDepth: maxDepth, warningType: .approaching)
        } else {
            depthWarning = nil  // 清除警告
        }
    }

    /// 清除深度警告（用户手动关闭）
    func dismissDepthWarning() {
        depthWarning = nil
    }
}
