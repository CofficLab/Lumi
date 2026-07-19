import Foundation

// MARK: - Layout State Info

/// 布局状态信息（轻量级数据结构）
public struct LayoutStateInfo: Sendable, Codable {
    public var activeSectionID: String
    public var activeSectionTitle: String

    public init(activeSectionID: String = "", activeSectionTitle: String = "") {
        self.activeSectionID = activeSectionID
        self.activeSectionTitle = activeSectionTitle
    }
}

// MARK: - Layout Capability Protocol

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