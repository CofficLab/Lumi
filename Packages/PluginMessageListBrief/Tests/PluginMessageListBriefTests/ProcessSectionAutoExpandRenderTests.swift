import AppKit
import Foundation
import ProviderAgentLoop
import ProviderMessage
import SwiftUI
import Testing
@testable import PluginMessageListBrief

/// 过程折叠区的**自动展开**渲染级验证。
///
/// ## 为什么必须做渲染级验证
///
/// 自动展开是这次改造的用户可见核心：「用户发送消息后过程区自动展开」。
/// 纯逻辑测试只能验证 `ProcessSectionExpansion` 这个状态机，
/// 测不出「它是否真的接进了 `AgentTurnView` 的渲染路径」——
/// 比如状态机对了但 `AgentTurnView` 忘了读 `expansion.isExpanded`，
/// 或者 `item.isShowingProcess` 的接线时机不对。
///
/// 这里渲染**真实的 `AgentTurnView`**，用真实的 `AgentTurnPresentationItem`
/// 断言过程区的内容是否出现在视图树里。
@MainActor
@Suite("过程折叠区自动展开的渲染级测试")
struct ProcessSectionAutoExpandRenderTests {
    /// 假的消息能力：按会话返回固定的消息快照。
    ///
    /// - Important: `AgentTurnVM` 通过 `services.messages` 读取消息来投影
    ///   过程区。渲染能力为 nil 时投影为空，过程区根本没有内容可渲染 ——
    ///   那样测的就不是「是否自动展开」而是「有没有内容」。
    final class StubMessageCapability: MessageListMessageCapability {
        var snapshot: [Message] = []

        func messagesSnapshot(in conversationID: UUID) async -> [Message] {
            snapshot
        }

        func messagePageAsync(
            for conversationID: UUID,
            limit: Int,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) async -> [Message] {
            []
        }

        func hasEarlierMessagesAsync(
            for conversationID: UUID,
            beforeMessageID: UUID?,
            includesToolMessages: Bool
        ) async -> Bool {
            false
        }
    }
    /// 渲染 `AgentTurnView`，返回渲染出的**内容高度**。
    ///
    /// - Important: 用高度而不是文本来判断「过程区是否展开」。
    ///   SwiftUI 的 `Text` 在 AppKit 视图树里不是 `NSTextField`
    ///   （实测渲染树的 `NSTextField` 数量为 0），文本提取不可靠；
    ///   而「展开的过程区有高度、折叠时没有」是直接且稳定的几何事实。
    private func renderTurnHeight(isShowingProcess: Bool) throws -> CGFloat {
        let conversationID = UUID()
        let turnID = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!

        let userMessage = Message(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            conversationID: conversationID,
            role: .user,
            content: "用户消息",
            createdAt: Date(),
            turnID: turnID
        )
        let processMessage = Message(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            conversationID: conversationID,
            role: .assistant,
            content: "步骤一的执行细节",
            createdAt: Date().addingTimeInterval(1),
            turnID: turnID
        )
        let finalMessage = Message(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            conversationID: conversationID,
            role: .assistant,
            content: "最终回复",
            createdAt: Date().addingTimeInterval(2),
            turnID: turnID
        )

        let record = AgentTurnRecord(
            id: turnID,
            conversationID: conversationID,
            startedAt: Date(),
            endedAt: isShowingProcess ? nil : Date().addingTimeInterval(3),
            state: isShowingProcess ? .running : .completed
        )
        let summary = AgentTurnSummaryItem(
            record: record,
            userMessage: userMessage,
            processMessages: [processMessage],
            message: finalMessage
        )
        let item = AgentTurnPresentationItem(
            recorded: summary,
            acceptsLiveActivity: isShowingProcess
        )

        let messageCapability = StubMessageCapability()
        messageCapability.snapshot = [userMessage, processMessage, finalMessage]
        let services = MessageListServices(
            conversations: nil,
            developerMode: nil,
            messages: messageCapability,
            rendering: nil,
            agentTurn: nil
        )
        let hosting = NSHostingView(
            rootView: AgentTurnView(
                services: services,
                item: item,
                verbosity: .standard,
                isDeveloperModeEnabled: false,
                viewportHeight: 800,
                turnVM: AgentTurnVM(services: services, item: item)
            )
        )
        hosting.frame = NSRect(x: 0, y: 0, width: 480, height: 800)
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView?.addSubview(hosting)
        window.makeKeyAndOrderFront(nil)
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        defer {
            window.orderOut(nil)
            hosting.removeFromSuperview()
        }

        return hosting.fittingSize.height
    }


    // MARK: - 用例

    @Test("活跃回合的过程区默认展开：用户不用点按钮就能看到 agent 的动作")
    func activeTurnShowsProcessByDefault() throws {
        let height = try renderTurnHeight(isShowingProcess: true)
        #expect(
            height > 130,
            """
            活跃回合的过程区应默认展开（自动展开），渲染高度应包含过程区的内容。\
            实测高度：\(height)pt
            """
        )
    }

    @Test("历史回合的过程区默认折叠：长会话不会被过程区刷屏")
    func historicalTurnHidesProcessByDefault() throws {
        let height = try renderTurnHeight(isShowingProcess: false)
        #expect(
            height <= 130,
            """
            历史回合的过程区应默认折叠，渲染高度不应包含过程区内容。\
            实测高度：\(height)pt
            """
        )
    }

    @Test("活跃回合比历史回合高：差值就是自动展开的过程区")
    func activeTurnIsTallerThanHistoricalTurn() throws {
        let activeHeight = try renderTurnHeight(isShowingProcess: true)
        let historicalHeight = try renderTurnHeight(isShowingProcess: false)
        #expect(
            activeHeight > historicalHeight,
            """
            活跃回合应因自动展开的过程区而更高。\
            活跃=\(activeHeight)pt 历史=\(historicalHeight)pt
            """
        )
    }
}
