import LumiUI
import ProviderConversation
import ProviderMessage
import SwiftUI

/// V1 中一个完整的 AgentTurn。
///
/// List 只负责排列多个本视图；用户消息、工具过程、流式消息和最终结果
/// 都在这里完成组合。当前对话状态由消息列表尾部的 ConversationStateView 展示。
/// pending Turn 使用用户消息 ID，真实 Turn 使用 turnID，确保多个历史/子 Turn
/// 在列表中始终拥有唯一身份。
struct AgentTurnView: View {
    let services: MessageListServices
    let item: AgentTurnPresentationItem
    let verbosity: ResponseVerbosity
    let isDeveloperModeEnabled: Bool

    /// 消息列表视口高度。过程折叠区的高度上限由它算出（视口的 60%）。
    let viewportHeight: CGFloat

    @ObservedObject private var turnVM: AgentTurnVM
    let onDynamicContentChange: (@MainActor () -> Void)?

    /// 过程折叠区的展开状态。
    ///
    /// - Important: 用 ``ProcessSectionExpansion`` 而不是裸 `@State Bool`。
    ///   它记住「用户是否曾手动操作过」，自动展开只在用户从未表达过
    ///   偏好时生效 —— 否则用户手动折叠后，每一轮流式更新都会把折叠区
    ///   又撑开，变成「强制展开」。
    /// - Important: 初始值按 `item.isShowingProcess` 构造 —— 活跃回合
    ///   默认展开（用户不用点按钮就能看到 agent 在干什么），历史回合
    ///   默认折叠（否则长会话会被几十个过程区刷屏）。
    @State private var expansion: ProcessSectionExpansion

    init(
        services: MessageListServices,
        item: AgentTurnPresentationItem,
        verbosity: ResponseVerbosity,
        isDeveloperModeEnabled: Bool,
        viewportHeight: CGFloat,
        turnVM: AgentTurnVM,
        onDynamicContentChange: (@MainActor () -> Void)? = nil
    ) {
        self.services = services
        self.item = item
        self.verbosity = verbosity
        self.isDeveloperModeEnabled = isDeveloperModeEnabled
        self.viewportHeight = viewportHeight
        _turnVM = ObservedObject(wrappedValue: turnVM)
        self.onDynamicContentChange = onDynamicContentChange
        _expansion = State(initialValue: ProcessSectionExpansion(isActive: item.isShowingProcess))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(turnVM.projection.userMessages) { message in
                messageRow(message)
            }

            // 有实际过程内容时才显示折叠区：
            // - 历史回合有过程消息（工具调用 / 中间状态）→ 显示
            // - 活跃回合有过程消息（已开始工具调用）→ 显示
            // - 活跃回合仅处于思考阶段、还没有过程消息 → 隐藏，由底部状态卡承担提示
            if !turnVM.projection.processMessages.isEmpty {
                processDisclosure
            }

            if let lastMessage = turnVM.projection.lastMessage {
                messageRow(lastMessage)
            }
        }
        .task { await turnVM.activate() }
        .onChange(of: item) { newItem in
            Task { await turnVM.update(item: newItem) }
        }
        .onChange(of: item.isShowingProcess) { isActive in
            // 回合开始（进入活跃状态）→ 自动展开过程区。
            // 若用户此前手动折叠过，这个调用不会覆盖用户的选择。
            expansion.turnStateChanged(isActive: isActive)
        }
        .onChange(of: turnVM.projection) { _ in
            onDynamicContentChange?()
        }
    }

    private var processDisclosure: some View {
        VStack(alignment: .leading, spacing: 8) {
            if item.isShowingProcess {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    processDisclosureButton(now: context.date)
                }
            } else {
                processDisclosureButton(now: .now)
            }

            if expansion.isExpanded {
                // 展开后的过程区限高（视口的 60%），超出部分在区内垂直滚动。
                //
                // - Important: 必须限高。过程区可能包含整段 LLM 回复正文与
                //   大量工具步骤，不限高时一次展开就能把整屏撑满、把外层
                //   列表顶出视口。
                // - Important: 高度上限依赖 `viewportHeight`，而它由
                //   `ListV1View` 的滚动底栏跟踪器测得。视口未就绪时
                //   `ProcessSectionLayout` 会回退到绝对下限，折叠区不会消失。
                BoundedProcessSection(
                    maxHeight: ProcessSectionLayout.maxHeight(viewportHeight: viewportHeight),
                    contentVersion: processContentVersion
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(turnVM.projection.processMessages) { message in
                            messageRow(message)
                        }
                    }
                }
                .accessibilityIdentifier(ProcessSectionAccessibility.container)
            }
        }
        // Only animate the disclosure container's height. Animating the whole
        // turn by message IDs makes List re-layout every child row at once,
        // which causes the surrounding rows to jump and the Markdown content
        // to flash while the process section is inserted.
        .animation(.easeInOut(duration: 0.2), value: expansion.isExpanded)
    }

    /// 过程区内容的版本号：内容每次变化递增，用于触发一次重新定位。
    ///
    /// - Important: 用「消息 id + 内容长度」的组合而不是消息数组本身。
    ///   消息数组的相等判定与「是否增长」无关（同样的消息集合可能对应
    ///   完全相同的状态），而定位逻辑只关心「有没有新内容进来」。
    /// - Important: 不使用 `String.hashValue`。它是**每次进程启动都会变的
    ///   随机种子**：同一条消息在不同进程里会得到不同的版本号，视图 identity
    ///   随之漂移。这里改用 UUID 的原始字节 —— 稳定、跨进程一致、无碰撞。
    private var processContentVersion: Int {
        var version = turnVM.projection.processMessages.count
        for message in turnVM.projection.processMessages {
            version = version &* 31 &+ message.id.stableHashValue
            version = version &* 31 &+ message.content.count
        }
        return version
    }

    private func processDisclosureButton(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                expansion.userToggled(toExpanded: !expansion.isExpanded)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: expansion.isExpanded ? "chevron.down" : "chevron.right")
                    Text(AgentTurnVM.processDisclosureTitle(
                        item: item,
                        userMessages: turnVM.projection.userMessages,
                        processMessages: turnVM.projection.processMessages,
                        now: now
                    ))
                }
                .font(.appCaption)
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
        }
    }

    private func messageRow(_ message: Message) -> some View {
        MessageRowView(
            services: services,
            message: message,
            verbosity: verbosity,
            isDeveloperModeEnabled: isDeveloperModeEnabled
        )
        .id(message.id)
    }
}

/// 过程折叠区的无障碍标识符。
///
/// UI 测试必须按标识符定位：折叠区的标题文案是随 `-AppleLanguages`
/// 变化的本地化文本，按文案定位在非英文环境下必然失败。
enum ProcessSectionAccessibility {
    /// 展开后的过程区容器。
    static let container = "lumi.message-list-brief.process-section"

    /// 内层滚动视图的实时几何（`offset/documentHeight/visibleHeight`）。
    ///
    /// - Note: 仅 DEBUG 存在。它是 UI 测试**唯一**能读到内层真实偏移的
    ///   通道 —— AX 帧对未物化的行会给出恒定的列表坐标，合成滚轮事件
    ///   又不被 SwiftUI 的 `ScrollView` 接受。
    static let geometry = "lumi.message-list-brief.process-section.geometry"
}
