import SwiftUI

@MainActor
public protocol ChatSectionProviding: AnyObject {
    var isVisible: Bool { get }
    var isContextActive: Bool { get }

    func addItems(_ items: [ChatSectionItem])
    func removeItem(id: String)
    func addBarItems(_ items: [ChatSectionBarItem])
    func removeBarItem(id: String)
    func setVisible(_ visible: Bool)
    func setContextActive(_ active: Bool)
    func makeChatSectionView() -> AnyView
}
