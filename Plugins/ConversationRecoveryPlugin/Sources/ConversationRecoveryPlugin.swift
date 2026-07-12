import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

/// 对话恢复插件
///
/// 当对话被中断（App 崩溃、用户主动停止、网络错误等）时，在聊天区域显示恢复横幅。
/// 用户可以选择恢复对话或忽略提示。
public enum ConversationRecoveryPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .agent
    public static let iconName = "arrow.clockwise.circle"
    public static let info = LumiPluginInfo(
        id: "plugin-conversation-recovery",
        displayName: LumiPluginLocalization.string("对话恢复", bundle: .module),
        description: LumiPluginLocalization.string("检测并恢复被中断的对话", bundle: .module),
        order: 79
    )

    @MainActor
    public static func chatSectionItems(context: LumiPluginContext) -> [LumiChatSectionItem] {
        guard context.showsChatSection,
              let coordinator = context.resolve(ChatSectionCoordinator.self)
        else {
            return []
        }

        return [
            LumiChatSectionItem(
                id: info.id,
                order: 0, // 显示在最顶部
                fillsRemainingHeight: false
            ) {
                ConversationRecoveryChatSectionView(coordinator: coordinator)
            }
        ]
    }

    @MainActor
    public static func onboardingPages(context: LumiPluginContext) -> [AnyView] {
        [
            AnyView(
                PluginOnboardingPageView(
                    icon: iconName,
                    displayName: info.displayName,
                    description: info.description,
                    features: [
                        .init(
                            icon: "arrow.clockwise",
                            title: LumiPluginLocalization.string("自动检测中断", bundle: .module),
                            description: LumiPluginLocalization.string("启动时自动检测被中断的对话", bundle: .module)
                        ),
                        .init(
                            icon: "checkmark.circle",
                            title: LumiPluginLocalization.string("一键恢复", bundle: .module),
                            description: LumiPluginLocalization.string("点击即可恢复对话", bundle: .module)
                        ),
                    ],
                    tip: LumiPluginLocalization.string("对话恢复横幅会在检测到中断时自动显示。", bundle: .module)
                )
            )
        ]
    }
}

private struct ConversationRecoveryChatSectionView: View {
    @LumiTheme private var theme
    @ObservedObject var coordinator: ChatSectionCoordinator

    var body: some View {
        ConversationRecoverySidebarView(
            conversationIdProvider: { coordinator.selectedConversationID },
            backgroundColorProvider: {
                theme.background.opacity(0.94)
            }
        )
    }
}
