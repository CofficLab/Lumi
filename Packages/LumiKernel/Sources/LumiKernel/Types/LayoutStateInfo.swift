import Foundation

/// 布局状态信息（轻量级数据结构）
public struct LayoutStateInfo: Sendable, Codable {
    public var activeSectionID: String
    public var activeSectionTitle: String

    public init(activeSectionID: String = "", activeSectionTitle: String = "") {
        self.activeSectionID = activeSectionID
        self.activeSectionTitle = activeSectionTitle
    }
}
