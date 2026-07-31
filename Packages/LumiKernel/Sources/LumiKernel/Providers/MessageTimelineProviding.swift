import Combine
import Foundation

/// 消息时间线数据源
///
/// 为"消息列表"类 UI 提供**可直接展示的行序列**,把以下知识收敛到数据层,
/// 让 UI 插件(如 `MessageListPlugin`)只负责展示、滚动、分页触发等纯 UI 职责:
///
/// - **行来源合并**:落库消息 + 流式临时行 + 发送中状态行,UI 拿到的
///   `displayRows` 已是最终序列,不区分来源、不关心消息类型。
/// - **分页数据策略**:首屏加载 / 向上翻页 / 尾部刷新 / 窗口回收,
///   UI 只通过 `activate` / `loadEarlier` / `refreshTail` 触发。
/// - **渲染器分发**:`renderer(for:)` 按消息匹配渲染器并附带当前会话的
///   `verbosity`;UI 拿到渲染器只做最终 `render()` 调用。
/// - **流式高频更新**:实现内部自行窄播订阅 streaming/sender 服务,
///   绕开 kernel 全局广播;本服务注册时同样不转发 objectWillChange
///   (见 `registerMessageTimelineProvider`),消费方用
///   `ObservableMessageTimelineBox` 精确订阅。
///
/// 本协议**不依赖 SwiftUI**:行序列以 `LumiChatMessage` 为货币,
/// 渲染器以 `LumiMessageRendererItem` 透出,最终的 View 构造由 UI 层完成。
@MainActor
public protocol MessageTimelineProviding: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// 当前会话的最终展示行序列(已合并落库 + 流式 + 状态行,按时间升序)。
    var displayRows: [LumiChatMessage] { get }

    /// 内存中是否已有真实落库消息;供 UI 判断空态
    /// (流式/状态行不算 —— 空态语义基于真实历史)。
    var hasPersistedMessages: Bool { get }

    /// 首屏 loading:切换会话时为 true,首屏数据就绪后置 false。
    var isLoading: Bool { get }

    /// 正在加载更早一页(UI 分页按钮的 loading 态)。
    var isLoadingEarlier: Bool { get }

    /// 顶部是否还有更早的消息未加载。
    var hasEarlierMessages: Bool { get }

    /// 当前流式行正文;供 UI 做"用户停在底部时的跟随滚动"。
    /// 内容未变时不发布,避免无意义的重估。
    var tailStreamingContent: String? { get }

    /// 当前会话的响应详细程度;由 UI 透传给渲染闭包,
    /// 渲染器可据此切换简洁/标准/详细外观。
    var verbosity: LumiResponseVerbosity { get }

    /// 切换/进入会话:加载最近一页。传 `nil` 清空时间线。
    func activate(conversationID: UUID?) async

    /// 向上翻页:加载更早一页并 prepend。
    ///
    /// - Parameter isAtBottom: 用户是否在底部(窗口回收策略需要,由 UI 传入)。
    /// - Returns: prepend 前最早一条消息的 id,UI 应把它钉回视口顶部;
    ///   `nil` 表示无需操作。
    func loadEarlier(isAtBottom: Bool) async -> UUID?

    /// 尾部刷新:重新查最近一页覆盖尾部(新消息到达 / 流式落库)。
    func refreshTail() async

    /// 查找可渲染指定消息的渲染器;`nil` 表示无匹配(UI 应显示占位)。
    func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem?
}
