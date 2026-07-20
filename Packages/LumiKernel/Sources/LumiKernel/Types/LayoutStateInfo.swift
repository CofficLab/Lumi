import Foundation

/// 布局状态信息（轻量级数据结构）
public struct LayoutStateInfo: Sendable, Codable {
    public var activeSectionID: String
    public var activeSectionTitle: String
    public var chatSectionVisible: Bool

    public init(
        activeSectionID: String = "",
        activeSectionTitle: String = "",
        chatSectionVisible: Bool = true
    ) {
        self.activeSectionID = activeSectionID
        self.activeSectionTitle = activeSectionTitle
        self.chatSectionVisible = chatSectionVisible
    }
}
