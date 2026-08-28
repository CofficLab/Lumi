import ProviderConversation
import Combine
import SwiftUI

/// 聊天分区宿主能力协议。
///
/// 对应旧版 KernelLumi 的 `ChatSection` 宿主行为（header / toolbar / 正文
/// stack+bottomFixed / action bar），插件通过它注册内容区与各栏贡献；
/// 宿主通过 `makeChatSectionView()` 渲染整个聊天分区。
@MainActor
public protocol ChatSectionProviding: AnyObject, ObservableObject
    where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 聊天分区整体是否可见（由容器切换驱动）。
    var isVisible: Bool { get }

    /// 聊天上下文是否激活（激活时才显示 header / toolbar）。
    var isContextActive: Bool { get }

    /// header / toolbar 是否显示。
    ///
    /// 复刻旧版 `ChatView` 语义：即使容器激活，没有选中会话时也隐藏
    /// header / toolbar，仅保留正文与输入区。默认跟随 `isContextActive`；
    /// 集成层可通过 `setHeaderVisible` 或 `bindConversationSelection`
    /// 让可见性跟随「是否存在选中会话」。
    var isHeaderVisible: Bool { get }

    func addItems(_ items: [ChatSectionItem])
    func removeItem(id: String)

    func addBarItems(_ items: [ChatSectionBarItem])
    func removeBarItem(id: String)

    /// 注册聊天分区根包装器（对应旧版 `chatSectionRootWrapper`）。
    func addRootWrappers(_ wrappers: [ChatSectionRootWrapper])
    func removeRootWrapper(id: String)

    func setVisible(_ visible: Bool)
    func setContextActive(_ active: Bool)
    func setHeaderVisible(_ visible: Bool)

    /// 把 header / toolbar 可见性绑定到会话选择状态：
    /// 无选中会话时自动隐藏（复刻旧版 `ChatView` 的 `selectedConversationID != nil` 判断）。
    ///
    /// 由集成层（FactoryLumi）在插件全部启动、`ConversationManaging` 最终实例
    /// 确定后调用一次；订阅随 Provider 生命周期持有。
    func bindConversationSelection(_ conversations: any ConversationManaging)

    func makeChatSectionView() -> AnyView
}

// MARK: - Defaults

public extension ChatSectionProviding {
    /// 默认跟随上下文激活；自定义实现可在需要时覆盖。
    var isHeaderVisible: Bool { isContextActive }

    func setHeaderVisible(_ visible: Bool) {}

    func addRootWrappers(_ wrappers: [ChatSectionRootWrapper]) {}

    func removeRootWrapper(id: String) {}

    func bindConversationSelection(_ conversations: any ConversationManaging) {}
}
