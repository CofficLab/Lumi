import Foundation

/// 布局能力协议
///
/// 定义 LumiCore 需要的布局管理功能，由 LumiCoreLayout 实现。
@MainActor
public protocol LayoutProviding: ObservableObject {
    /// 布局状态（轻量级信息，用于持久化）
    var state: LayoutStateInfo { get }

    /// 原始布局状态（包含 @Published 属性，用于视图绑定）
    var layoutState: LayoutState { get }

    /// 更新布局
    func updateLayout(_ update: (inout LayoutStateInfo) -> Void)
}
