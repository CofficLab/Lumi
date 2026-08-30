import ProviderConversation
import Combine
import Foundation
import SwiftUI

// MARK: - Chat Section Width

/// ChatSection 右侧面板的宽度约束。
@MainActor
public struct ChatSectionWidth: Equatable, Sendable {
    public let minWidth: CGFloat
    public let idealWidth: CGFloat
    public let maxWidth: CGFloat

    public static let standard = Self(minWidth: 280, idealWidth: 320, maxWidth: .infinity)

    public init(minWidth: CGFloat, idealWidth: CGFloat, maxWidth: CGFloat) {
        let safeMin = minWidth.isFinite ? max(0, minWidth) : 0
        let safeMax: CGFloat
        if maxWidth.isFinite {
            safeMax = max(safeMin, maxWidth)
        } else {
            safeMax = .infinity
        }
        self.minWidth = safeMin
        self.maxWidth = safeMax
        self.idealWidth = Self.clamp(idealWidth, min: safeMin, max: safeMax)
    }

    public func withIdealWidth(_ width: CGFloat) -> Self {
        Self(minWidth: minWidth, idealWidth: width, maxWidth: maxWidth)
    }

    public func clamped(_ width: CGFloat) -> CGFloat {
        Self.clamp(width, min: minWidth, max: maxWidth)
    }

    private static func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        let safeValue = value.isFinite ? value : minimum
        return Swift.min(Swift.max(safeValue, minimum), maximum)
    }
}

/// ChatSection 宽度偏好的持久化接口。
///
/// 该接口由插件持有并注入 ChatSection provider；插件可以决定文件位置和存储生命周期。
@MainActor
public protocol ChatSectionWidthStoring: AnyObject {
    func loadWidth(ownerID: String) -> CGFloat?
    func saveWidth(_ width: CGFloat, ownerID: String)
    func removeWidth(ownerID: String)
}

/// 基于 binary plist 的 ChatSection 宽度存储。
///
/// 文件位置由插件通过 `fileURL` 注入，通常放在插件自己的数据目录。
@MainActor
public final class FileChatSectionWidthStore: ChatSectionWidthStoring {
    private let fileURL: URL
    private var values: [String: Double]

    public init(fileURL: URL) {
        self.fileURL = fileURL
        self.values = Self.load(from: fileURL)
    }

    public func loadWidth(ownerID: String) -> CGFloat? {
        guard let value = values[ownerID], value.isFinite, value > 0 else { return nil }
        return CGFloat(value)
    }

    public func saveWidth(_ width: CGFloat, ownerID: String) {
        guard !ownerID.isEmpty, width.isFinite, width > 0 else { return }
        values[ownerID] = Double(width)
        persist()
    }

    public func removeWidth(ownerID: String) {
        guard values.removeValue(forKey: ownerID) != nil else { return }
        persist()
    }

    private func persist() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(
                fromPropertyList: values,
                format: .binary,
                options: 0
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Keep the in-memory preference effective if the disk is unavailable.
        }
    }

    private static func load(from url: URL) -> [String: Double] {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let values = plist as? [String: Double] else {
            return [:]
        }
        return values
    }
}

/// 聊天分区状态变更事件。
@MainActor
public enum ChatSectionProvidingEvent {
    case itemsChanged([ChatSectionItem])
    case barItemsChanged([ChatSectionBarItem])
    case rootWrappersChanged([ChatSectionRootWrapper])
    case visibilityChanged(Bool)
    case contextActiveChanged(Bool)
    case activeContextChanged(ChatContext?)
    case headerVisibilityChanged(Bool)
}

/// 聊天分区状态观察句柄。
@MainActor
public protocol ChatSectionProvidingObserverHandle: AnyObject {
    func cancel()
}

@MainActor
public final class NoopChatSectionProvidingObserverHandle: ChatSectionProvidingObserverHandle {
    public init() {}
    public func cancel() {}
}

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

    /// 当前激活的聊天工作台上下文。`nil` 表示没有插件工作台上下文。
    var activeContext: ChatContext? { get }

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
    func setActiveContext(_ context: ChatContext?)
    func setHeaderVisible(_ visible: Bool)

    /// 注册聊天分区状态观察者。回调在状态更新后同步执行。
    @discardableResult
    func addObserver(_ callback: @escaping (ChatSectionProvidingEvent) -> Void) -> any ChatSectionProvidingObserverHandle

    /// 把 header / toolbar 可见性绑定到会话选择状态：
    /// 无选中会话时自动隐藏（复刻旧版 `ChatView` 的 `selectedConversationID != nil` 判断）。
    ///
    /// 由集成层（FactoryLumi）在插件全部启动、`ConversationManaging` 最终实例
    /// 确定后调用一次；订阅随 Provider 生命周期持有。
    func bindConversationSelection(_ conversations: any ConversationManaging)

    /// 当前 ChatSection 的有效宽度。
    var chatSectionWidth: ChatSectionWidth { get }

    /// ChatSection 宽度变化发布器。
    var chatSectionWidthPublisher: AnyPublisher<ChatSectionWidth, Never> { get }

    /// 激活插件的 ChatSection 宽度配置。
    ///
    /// provider 会优先从插件注入的 store 恢复宽度；没有保存值时才使用
    /// `recommended` 的 `idealWidth`。owner ID 必须是插件稳定标识。
    func activateWidthProfile(
        ownerID: String,
        recommended: ChatSectionWidth,
        store: (any ChatSectionWidthStoring)?
    )

    /// 停用插件的 ChatSection 宽度配置。其他插件已经接管时不会覆盖其当前配置。
    func deactivateWidthProfile(ownerID: String)

    /// 保存当前激活插件的用户拖拽宽度。
    func saveCurrentWidth(_ width: CGFloat)

    func makeChatSectionView() -> AnyView
}

// MARK: - Defaults

public extension ChatSectionProviding {
    /// 默认跟随上下文激活；自定义实现可在需要时覆盖。
    var isHeaderVisible: Bool { isContextActive }

    var activeContext: ChatContext? { nil }

    func setHeaderVisible(_ visible: Bool) {}

    func setActiveContext(_ context: ChatContext?) {}

    func addRootWrappers(_ wrappers: [ChatSectionRootWrapper]) {}

    func removeRootWrapper(id: String) {}

    func bindConversationSelection(_ conversations: any ConversationManaging) {}

    var chatSectionWidth: ChatSectionWidth { .standard }

    var chatSectionWidthPublisher: AnyPublisher<ChatSectionWidth, Never> {
        Just(chatSectionWidth).eraseToAnyPublisher()
    }

    func activateWidthProfile(ownerID: String, recommended: ChatSectionWidth) {
        activateWidthProfile(ownerID: ownerID, recommended: recommended, store: nil)
    }

    func activateWidthProfile(
        ownerID: String,
        recommended: ChatSectionWidth,
        store: (any ChatSectionWidthStoring)?
    ) {}

    func deactivateWidthProfile(ownerID: String) {}

    func saveCurrentWidth(_ width: CGFloat) {}

    /// 默认空实现，保持轻量替身和自定义实现兼容。
    @discardableResult
    func addObserver(_ callback: @escaping (ChatSectionProvidingEvent) -> Void) -> any ChatSectionProvidingObserverHandle {
        NoopChatSectionProvidingObserverHandle()
    }
}
