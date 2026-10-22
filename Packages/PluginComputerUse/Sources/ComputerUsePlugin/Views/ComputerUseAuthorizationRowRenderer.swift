import Foundation
import KernelCore
import KitAgentTool
import LumiUI
import ProviderAgentLoop
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import SwiftUI

/// Computer Use 授权卡片的无障碍标识符。
///
/// UI 测试必须按标识符定位按钮：按钮文案是随 `-AppleLanguages` 变化的
/// 本地化文本，按文案定位在非英文环境下必然失败。
enum ComputerUseAuthorizationAccessibility {
    static let card = "lumi.computer-use-authorization.card"
    static let question = "lumi.computer-use-authorization.question"
    static let application = "lumi.computer-use-authorization.application"
    static func button(_ decision: ComputerUseAuthorizationDecision) -> String {
        "lumi.computer-use-authorization.\(decision.rawValue)"
    }
}

/// Computer Use 授权卡片的行渲染器。
///
/// 只在工具**挂起等待授权**时渲染：结果标记为 `awaitingUserResponse`，
/// 且载荷确实是 Computer Use 授权请求。一旦用户做出决定、工具重新执行
/// 完成，卡片自然消失。
///
/// - Note: 判定**不以 `authorizationState == .pendingAuthorization` 为前提**。
///   授权状态在 LLM 响应阶段就已写定：A3（完全授权）对话下一律是
///   `autoApproved`，而工具可以在执行阶段自己要求用户授权（如 Computer Use
///   遇到未授权应用）。若强依赖 `pendingAuthorization`，这类挂起就不会画卡片，
///   回合会等一个永远不会到来的回答，界面永久停在「等待你的输入…」。
///   载荷本身才是「这是一次 Computer Use 授权请求」的可靠证据。
///
/// - Note: priority 必须高于通用工具授权卡片（`ToolApprovalRowRenderer`
///   的 120），否则 Computer Use 的授权请求会被通用渲染器抢走，
///   退化成「允许 / 拒绝」两按钮，失去「允许一次 / 始终允许」语义。
struct ComputerUseAuthorizationRowRenderer: ToolCallRowRenderer {
    static let id = "computer-use-authorization-row"
    static let priority = 200

    private let coordinator: ComputerUseAuthorizationCoordinator

    init(coordinator: ComputerUseAuthorizationCoordinator? = nil) {
        self.coordinator = coordinator ?? .shared
    }

    public func canRender(toolCall: ToolCall) -> Bool {
        // 用户已做出决定后不得再渲染：否则界面会一直等一个已经给出的答案。
        guard toolCall.authorizationState != .userApproved,
              toolCall.authorizationState != .userRejected,
              toolCall.result?.awaitingUserResponse == true,
              let content = toolCall.result?.content
        else { return false }
        // 只有载荷确实是 Computer Use 授权请求时才接管，避免误抢其他挂起卡片。
        return coordinator.request(from: content) != nil
    }

    @MainActor
    public func render(toolCall: ToolCall, message: ToolCallRowMessageContext) -> AnyView {
        guard let content = toolCall.result?.content,
              let request = coordinator.request(from: content) else {
            return AnyView(Text(""))
        }
        return AnyView(
            ComputerUseAuthorizationCard(
                request: request,
                toolCall: toolCall,
                conversationID: message.conversationId
            )
        )
    }
}

/// Computer Use 授权卡片视图。
///
/// 展示目标应用与即将执行的操作，提供「允许一次 / 始终允许 / 拒绝」三个决定。
struct ComputerUseAuthorizationCard: View {
    @LumiTheme private var theme

    let request: ComputerUseAuthorizationRequest
    let toolCall: ToolCall
    let conversationID: UUID

    @State private var responded = false

    var body: some View {
        AppCard(
            style: .subtle,
            cornerRadius: 10,
            padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12),
            showShadow: false
        ) {
            VStack(alignment: .leading, spacing: 10) {
                header

                Text(request.operation)
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)

                buttons

                if responded {
                    Text(pluginLocalization.string("Submitted: waiting to continue…"))
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        // - Important: 必须显式 `children: .contain`。否则 SwiftUI 会把卡片当作
        //   一个整体元素，把容器上的 identifier 覆盖到所有后代，子元素最终统统
        //   报告同一个 id，UI 测试无法按标识符区分三个按钮
        //   （与 `ToolApprovalPendingView` 同一坑）。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ComputerUseAuthorizationAccessibility.card)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.raised.square.fill")
                .foregroundColor(theme.primary)
            Text(
                pluginLocalization
                    .string("Lumi wants to use {app}")
                    .replacingOccurrences(of: "{app}", with: request.applicationName)
            )
            .font(.appCaption)
            .foregroundColor(theme.textPrimary)
            .accessibilityIdentifier(ComputerUseAuthorizationAccessibility.question)

            Spacer(minLength: 0)

            Text(request.bundleIdentifier)
                .font(.appMicro)
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityIdentifier(ComputerUseAuthorizationAccessibility.application)
        }
    }

    private var buttons: some View {
        HStack(spacing: 8) {
            ForEach(ComputerUseAuthorizationDecision.allCases, id: \.self) { decision in
                AppButton(
                    decision.displayTitle,
                    systemImage: decision.systemImage,
                    style: buttonStyle(for: decision),
                    size: .small,
                    fillsWidth: true
                ) {
                    submit(decision)
                }
                .disabled(responded)
                .accessibilityIdentifier(ComputerUseAuthorizationAccessibility.button(decision))
            }
        }
    }

    private func buttonStyle(for decision: ComputerUseAuthorizationDecision) -> AppButton.Style {
        switch decision {
        case .allowOnce: return .primary
        case .alwaysAllow: return .warning
        case .deny: return .destructive
        }
    }

    /// 把决策交给桥接层落地：写入授权存储 → 恢复挂起的回合。
    private func submit(_ decision: ComputerUseAuthorizationDecision) {
        guard !responded else { return }
        responded = true
        ComputerUseAuthorizationBridge.shared.resolve(
            conversationID: conversationID,
            toolCall: toolCall,
            request: request,
            decision: decision
        )
    }
}

/// 把卡片上的决定送回等待中的 agent。
///
/// 与 `ToolApprovalBridge` 的分工一致：UI 只负责采集决定，
/// 由本桥接层落地授权并驱动回合恢复。
@MainActor
final class ComputerUseAuthorizationBridge {
    static let shared = ComputerUseAuthorizationBridge()

    private weak var messageSender: (any MessageSendingProviding)?
    private weak var agentLoop: (any AgentLoopProviding)?
    private let coordinator: ComputerUseAuthorizationCoordinator

    init(coordinator: ComputerUseAuthorizationCoordinator = .shared) {
        self.coordinator = coordinator
    }

    func start(kernel: KernelCoreContainer) {
        messageSender = kernel.resolveProvider((any MessageSendingProviding).self)
        agentLoop = kernel.resolveProvider((any AgentLoopProviding).self)
    }

    func stop() {
        messageSender = nil
        agentLoop = nil
    }

    /// 落地决策并恢复回合。
    func resolve(
        conversationID: UUID,
        toolCall: ToolCall,
        request: ComputerUseAuthorizationRequest,
        decision: ComputerUseAuthorizationDecision
    ) {
        // 先落授权再恢复：恢复后工具会被重新执行，届时授权必须已经生效。
        let message = coordinator.apply(decision: decision, request: request)
        let answer = "\(ComputerUseAuthorizationResolver.token(for: decision))\n\(message)"

        guard let messageSender else {
            ComputerUseAuthorizationCoordinator.logger.error(
                "\(ComputerUseAuthorizationCoordinator.t)MessageSender 不可用，无法恢复回合"
            )
            return
        }
        ComputerUseAuthorizationCoordinator.logger.info(
            "\(ComputerUseAuthorizationCoordinator.t)用户决策已落地 decision=\(decision.rawValue, privacy: .public) app=\(request.bundleIdentifier, privacy: .public)"
        )
        Task { @MainActor in
            _ = try? await messageSender.resumeTurn(
                in: conversationID,
                request: AgentTurnResumeRequest(
                    suspensionID: "userInput:\(toolCall.id)",
                    answer: answer
                )
            )
        }
    }
}