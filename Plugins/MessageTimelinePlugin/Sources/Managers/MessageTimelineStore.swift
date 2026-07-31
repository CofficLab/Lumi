import Combine
import Foundation
import LumiKernel
import os
import SuperLogKit

/// Message Timeline Store
///
/// `MessageTimelineProviding` 的实现:消息列表的**数据源**,承担全部"消息知识",
/// 让消息列表 UI(如 `MessageListPlugin`)成为纯展示组件:
///
/// - **分页数据**:首屏加载 / 向上翻页 / 尾部刷新 / 窗口回收,
///   委托给 `MessageTimelinePaginationService`,本类只持有状态与过期结果丢弃判定。
/// - **行合并**:真实消息 + 流式临时行 + 发送中状态行,委托给
///   `MessageTimelineRowBuilder`;UI 只面对已准备好的 `displayRows`,
///   不再区分行的来源与类型。
/// - **verbosity**:UI 直接从 `kernel.conversationManager` 获取。
///
/// 流式/发送服务的变化通过**窄播订阅**(直接订阅服务的 objectWillChange)
/// 触发展示行重算,绕开 kernel 的全局 objectWillChange 广播 ——
/// 流式期间 store 每个 token 都更新,若经 kernel 广播会拖慢整个 app。
///
/// 本类型是**纯数据层**:不依赖 SwiftUI,行序列以 `LumiChatMessage` 为货币,
/// 渲染器由 UI 层直接从 `kernel.messageRendererManager` 获取。
///
/// - SeeAlso: `MessageTimelinePaginationService`(分页策略)、
///   `MessageTimelineRowBuilder`(行合并规则)。
@MainActor
public final class MessageTimelineStore: MessageTimelineProviding, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.message-timeline-store")
    public nonisolated static let emoji = "📜"
    nonisolated static let verbose = true

    // MARK: - Published State (供 UI 展示)

    /// 最终展示行序列:真实消息 + 流式临时行 + 状态行(由 RowBuilder 合并)。
    @Published public private(set) var displayRows: [LumiChatMessage] = []

    /// 内存中的真实落库消息(分页窗口),按时间升序;`hasPersistedMessages` 由它派生。
    /// 任何变更都会触发 `rebuildRows` 重算展示行。
    @Published private(set) var persistedMessages: [LumiChatMessage] = [] {
        didSet { rebuildRows() }
    }

    /// 顶部是否还有更早的消息未加载。
    @Published public private(set) var hasEarlierMessages = false
    /// 首屏 loading:切换会话时为 true,首屏数据就绪后置 false。
    @Published public private(set) var isLoading = true
    /// 正在加载更早一页(分页按钮的 loading 态)。
    @Published public private(set) var isLoadingEarlier = false
    /// 当前流式行正文;UI 监听它做"用户停在底部时的跟随滚动"。
    /// 内容未变时不发布,避免无意义的重估。
    @Published public private(set) var tailStreamingContent: String?

    // MARK: - Dependencies & Internal State

    private let kernel: LumiKernel
    private let pagination = MessageTimelinePaginationService()
    private let rowBuilder = MessageTimelineRowBuilder()

    /// 切换会话时记录的目标会话,用于丢弃过期的后台读结果。
    private var activeConversationID: UUID?
    private var cancellables: Set<AnyCancellable> = []
    /// 流式/发送服务是否都已绑定;服务后于本 store 就绪时由 `activate` 重试绑定。
    private var didBindServices = false

    public init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    // MARK: - MessageTimelineProviding (Read-only)

    /// 内存中是否已有真实落库消息;供 UI 判断空态。
    public var hasPersistedMessages: Bool {
        !persistedMessages.isEmpty
    }

    private var selectedConversationID: UUID? {
        kernel.conversations?.selectedConversationID
    }

    /// 当前会话的响应详细程度;由 UI 透传给渲染闭包,
    /// 渲染器可据此切换简洁/标准/详细外观。
    public var verbosity: LumiResponseVerbosity {
        kernel.conversationManager?
            .verbosity(for: selectedConversationID) ?? .defaultVerbosity
    }

    // MARK: - Lifecycle

    /// 切换/进入会话:绑定服务订阅(幂等),记录目标会话,加载最近一页。
    public func activate(conversationID: UUID?) async {
        if Self.verbose {
            Self.logger.info("\(Self.t)🔄 activate 开始 ➡️ conversation=\(conversationID?.uuidString.prefix(8) ?? "nil")")
        }
        bindServicesIfNeeded()
        activeConversationID = conversationID
        isLoading = true
        await loadFirstPage(conversationID: conversationID)
    }

    // MARK: - Pagination

    /// 向上翻页:加载更早一页并 prepend,触发窗口回收。
    ///
    /// - Parameter isAtBottom: 用户是否在底部(窗口回收策略需要,由 UI 传入)。
    /// - Returns: prepend 前最早一条消息的 id,UI 应把它钉回视口顶部;
    ///   `nil` 表示无需操作。
    public func loadEarlier(isAtBottom: Bool) async -> UUID? {
        guard let conversationID = selectedConversationID,
              !isLoadingEarlier,
              let currentFirstID = persistedMessages.first?.id else { return nil }
        if Self.verbose {
            Self.logger.info("\(Self.t)⬆️ loadEarlier 开始 ➡️ conversation=\(conversationID.uuidString.prefix(8))…")
        }
        isLoadingEarlier = true
        defer { isLoadingEarlier = false }
        guard let result = await pagination.loadEarlier(
            conversationID: conversationID,
            messageManager: kernel.messageManager,
            currentFirstID: currentFirstID,
            hasEarlier: hasEarlierMessages
        ) else { return nil }
        // 加载期间用户可能切了会话,丢弃过期结果。
        guard activeConversationID == conversationID else {
            if Self.verbose {
                Self.logger.info("\(Self.t)⬆️ loadEarlier 过期丢弃")
            }
            return nil
        }
        persistedMessages = result.earlier + persistedMessages
        hasEarlierMessages = result.hasEarlierMessages
        persistedMessages = pagination.evictTailIfNeeded(
            messages: persistedMessages, isAtBottom: isAtBottom
        )
        return result.anchorID
    }

    /// 尾部刷新:重新查最近一页,与当前尾部比对并覆盖(新消息到达 / 流式落库)。
    ///
    /// 只作用于真实落库消息;流式临时行由流式服务独立持有,
    /// 经 `rebuildRows` 参与合并,无需任何特例处理。
    public func refreshTail() async {
        guard let conversationID = selectedConversationID else { return }
        if Self.verbose {
            Self.logger.info("\(Self.t)🔄 refreshTail 开始 ➡️ conversation=\(conversationID.uuidString.prefix(8))…")
        }
        guard let result = await pagination.refreshTail(
            conversationID: conversationID,
            messageManager: kernel.messageManager,
            current: persistedMessages
        ) else { return }
        guard activeConversationID == conversationID else {
            if Self.verbose {
                Self.logger.info("\(Self.t)🔄 refreshTail 过期丢弃")
            }
            return
        }
        persistedMessages = result.merged
        if let hasEarlier = result.hasEarlierMessages {
            hasEarlierMessages = hasEarlier
        }
    }

    // MARK: - Private

    /// 首屏:加载最近一页,并探测是否还有更早消息。
    private func loadFirstPage(conversationID: UUID?) async {
        guard let conversationID else {
            if Self.verbose {
                Self.logger.info("\(Self.t)📄 loadFirstPage ➡️ conversationID 为空,清空消息")
            }
            persistedMessages = []
            hasEarlierMessages = false
            isLoading = false
            return
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)📄 loadFirstPage 开始 ➡️ conversation=\(conversationID.uuidString.prefix(8))…")
        }
        let result = await pagination.loadFirstPage(
            conversationID: conversationID,
            messageManager: kernel.messageManager
        )
        // 切换会话期间用户可能又选了别的会话,丢弃过期结果。
        guard activeConversationID == conversationID else {
            if Self.verbose {
                Self.logger.info("\(Self.t)📄 loadFirstPage 过期丢弃")
            }
            return
        }
        persistedMessages = result.messages
        hasEarlierMessages = result.hasEarlierMessages
        if Self.verbose {
            Self.logger.info("\(Self.t)📄 loadFirstPage 完成 ➡️ messages=\(result.messages.count), hasEarlier=\(result.hasEarlierMessages)")
        }
        isLoading = false
    }

    /// 订阅流式/发送服务的窄播(绕开 kernel 全局广播),变化时重算展示行。
    ///
    /// `receive(on:)` 让 sink 在属性写入完成后异步执行
    /// (objectWillChange 在 willSet 触发,同步读取会拿到旧值)。
    /// 幂等:两个服务都绑定后不再重复;任一尚未就绪时由下次 `activate` 重试。
    private func bindServicesIfNeeded() {
        guard !didBindServices else { return }
        if let streaming = kernel.messageStreaming {
            streaming.objectWillChange
                .map { _ in () }
                .eraseToAnyPublisher()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.rebuildRows() }
                .store(in: &cancellables)
        }
        if let sender = kernel.messageSender {
            sender.objectWillChange
                .map { _ in () }
                .eraseToAnyPublisher()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.rebuildRows() }
                .store(in: &cancellables)
        }
        didBindServices = kernel.messageStreaming != nil && kernel.messageSender != nil
    }

    /// 重算展示行:真实消息 + 流式临时行 + 状态行。
    /// 切会话时其他会话的流式行会被 RowBuilder 按 conversationID 自动过滤。
    private func rebuildRows() {
        displayRows = rowBuilder.build(
            persisted: persistedMessages,
            conversationID: selectedConversationID,
            sender: kernel.messageSender,
            streaming: kernel.messageStreaming
        )
        let content = kernel.messageStreaming?.currentStreamingRow?.content
        if tailStreamingContent != content {
            tailStreamingContent = content
        }
    }
}
