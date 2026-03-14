import OSLog
import MagicKit
import SwiftUI

/// 新会话按钮视图组件
/// 点击时创建新会话，使用 AgentVM 内核方法完成所有操作
struct NewChatButton: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "🆕"
    /// 是否启用详细日志
    nonisolated static let verbose = false

    /// 环境对象：Agent 提供者
    @EnvironmentObject var agentProvider: AgentVM

    /// 图标尺寸常量
    private let iconSize: CGFloat = 14
    private let iconButtonSize: CGFloat = 28

    enum Style {
        /// 顶部栏图标按钮
        case iconOnly
        /// 空态等场景的大按钮
        case cta
    }

    var style: Style = .iconOnly

    var body: some View {
        Button {
            Task {
                await agentProvider.createNewConversation()
            }
        } label: {
            switch style {
            case .iconOnly:
                Image(systemName: "plus.circle")
                    .font(.system(size: iconSize))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    .frame(width: iconButtonSize, height: iconButtonSize)
                    .background(Color.black.opacity(0.05))
                    .clipShape(Circle())
            case .cta:
                Label("新建对话", systemImage: "plus.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .help("开启新会话")
    }
}

#Preview("New Chat Button - Small") {
    NewChatButton()
        .padding()
        .background(Color.black)
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("New Chat Button - Large") {
    NewChatButton(style: .cta)
        .padding()
        .background(Color.black)
        .inRootView()
        .frame(width: 1200, height: 1200)
}

