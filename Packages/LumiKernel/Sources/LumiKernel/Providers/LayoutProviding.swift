import Foundation

/// 布局能力协议
///
/// 定义 LumiCore 需要的布局管理功能，由 LumiCoreLayout 实现。
@MainActor
public protocol LayoutProviding: ObservableObject {
    /// 布局状态
    var state: LayoutStateInfo { get }

    /// 更新布局
    func updateLayout(_ update: (inout LayoutStateInfo) -> Void)
}
