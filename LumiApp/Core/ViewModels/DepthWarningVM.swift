import SwiftUI
import Foundation

/// 深度警告 ViewModel
@MainActor
final class DepthWarningVM: ObservableObject {
    /// 当前深度警告
    @Published public fileprivate(set) var depthWarning: DepthWarning?

    /// 设置深度警告
    func setDepthWarning(_ warning: DepthWarning?) {
        depthWarning = warning
    }

    /// 关闭深度警告
    func dismissDepthWarning() {
        depthWarning = nil
    }
}
