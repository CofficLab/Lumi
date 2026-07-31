import Combine
import Foundation
import LumiKernel

/// Message List View Model
///
/// 承担消息列表的全部"消息知识",让 `MessageListView` 成为纯展示组件:
///
/// - **分页数据**:首屏加载 / 向上翻页 / 尾部刷新 / 窗口回收,
///   委托给 `MessagePaginationService`,本类只持有状态与过期结果丢弃判定。
/// - **行合并**:真实消息 + 流式临时行 + 发送中状态行,委托给
///   `MessageListRowBuilder`;View 只面对已准备好的 `displayRows`,
///   不再区分行的来源。
/// - **渲染分发**:`renderer(for:)` 与 `verbosity`,View 不再接触
///   `messageRendererManager` / `conversationManager`。
///
/// 流式/发送服务的变化通过**窄播订阅**(直接订阅服务的 objectWillChange)
/// 触发展示行重算,绕开 kernel 的全局 objectWillChange 广播 ——
/// 流式期间 store 每个 token 都更新,若经 kernel 广播会拖慢整个 app。
///
/// - SeeAlso: `MessagePaginationService`(分页策略)、`MessageListRowBuilder`(行合并规则)。
@MainActor
final class MessageListViewModel: ObservableObject {
    // MARK: - Published State (供 View 展示)

    /// 最终展示行序列:真实消息 + 流式临时行 + 状态行(由 RowBuilder 合并)。
    @Published private(set) var displayRows: [LumiChatMessage] = []

    /// 内存中的真实落库消息(分页窗口),按时间升序;View 用它判断空态。
    /// 任何变更都会触发 `rebuildRows` 重算展示行。
    @Published private(set) var persistedMessages: [LumiChatMessage] = [] {
        didSet { rebuildRows() }
    }

    /// 顶部是否还有更早的消息未加载。
    @Published private(set) var hasEarlierMessages = false
    /// 首屏 loading:切换会话时为 true,首屏数据就绪后置 false。
    @Published private(set) var isLoading = true
    /// 正在加载更早一页(顶部按钮的 loading 态)。
    @Published private(set) var isLoadingEarlier = false
    /// 当前流式行正文;View 监听它做"用户停在底部时的跟随滚动"。
    /// 内容未变时不发布,避免无意义的 View 重估。
    @Published private(set) var tailStreamingContent: String?

    // MARK: - Dependencies & Internal State

    private let kernel: LumiKernel
    private let pagination = MessagePaginationService()
    private let rowBuilder = MessageListRowBuilder()

    /// 切换会话时记录的目标会话,用于丢弃过期的后台读结果。
    private var activeConversationID: UUID?
    private var cancellables: Set<AnyCancellable> = []
    /// 流式/发送服务是否都已绑定;服务后于 View 就绪时由 `activate` 重试绑定。
    private var didBindServices = false

    init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    // MARK: - Read-only Accessors (View 展示用)

    var selectedConversationID: UUID? {
        kernel.conversations?.selectedConversationID
    }

    /// 当前会话的响应详细程度;由 View 透传给渲染闭包,
    /// 渲染器可据此切换简洁/标准/详细外观。
    var verbosity: LumiResponseVerbosity {
        kernel.conversationManager?
            .verbosity(for: selectedConversationID) ?? .defaultVerbosity
    }

    func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem? {
        kernel.messageRendererManager?.renderer(for: message)
    }

    // MARK: - Lifecycle

    /// 切换/进入会话:绑定服务订阅(幂等),记录目标会话,加载最近一页。
    func activate(conversationID: UUID?) async {
        bindServicesIfNeeded()
        activeConversationID = conversationID
        isLoading = true
        await loadFirstPage()
    }

    // MARK: - Pagination

    /// 向上翻页:加载更早一页并 prepend,触发窗口回收。
    ///
    /// - Parameter isAtBottom: 用户是否在底部(窗口回收策略需要,由 View 传入)。
    /// - Returns: prepend 前最早一条消息的 id,View 应把它钉回视口顶部;
    ///   `nil` 表示无需操作。
    func loadEarlier(isAtBottom: Bool) async -> UUID? {
        guard let conversationID = selectedConversationID,
              !isLoadingEarlier,
              let currentFirstID = persistedMessages.first?.id else { return nil }
        isLoadingEarlier = true
        defer { isLoadingEarlier = false }
        guard let result = await pagination.loadEarlier(
            conversationID: conversationID,
            messageManager: kernel.messageManager,
            currentFirstID: currentFirstID,
            hasEarlier: hasEarlierMessages
        ) else { return nil }
        // 加载期间用户可能切了会话,丢弃过期结果。
        guard activeConversationID == conversationID else { return nil }
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
    func refreshTail() async {
        guard let conversationID = selectedConversationID else { return }
        guard let result = await pagination.refreshTail(
            conversationID: conversationID,
            messageManager: kernel.messageManager,
            current: persistedMessages
        ) else { return }
        guard activeConversationID == conversationID else { return }
        persistedMessages = result.merged
        if let hasEarlier = result.hasEarlierMessages {
            hasEarlierMessages = hasEarlier
        }
    }

    // MARK: - Private

    /// 首屏:加载最近一页,并探测是否还有更早消息。
    private func loadFirstPage() async {
        guard let conversationID = selectedConversationID else {
            persistedMessages = []
            hasEarlierMessages = false
            isLoading = false
            return
        }
        let result = await pagination.loadFirstPage(
            conversationID: conversationID,
            messageManager: kernel.messageManager
        )
        // 切换会话期间用户可能又选了别的会话,丢弃过期结果。
        guard activeConversationID == conversationID else { return }
        persistedMessages = result.messages
        hasEarlierMessages = result.hasEarlierMessages
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
