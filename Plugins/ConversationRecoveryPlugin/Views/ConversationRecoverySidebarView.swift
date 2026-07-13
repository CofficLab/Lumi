import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

/// 对话恢复侧边栏视图
///
/// 显示被中断的对话信息和恢复按钮，由 ConversationRecoveryPlugin 通过 `chatSectionItems` 注册。
public struct ConversationRecoverySidebarView: View {
    @StateObject private var viewModel = ConversationRecoveryViewModel()
    @State private var isCollapsed = false

    /// 获取当前会话 ID 的闭包
    private let conversationIdProvider: () -> UUID?

    /// 获取背景色的闭包
    private let backgroundColorProvider: () -> Color

    private static let headerHeight: CGFloat = 44
    private static let contentHeight: CGFloat = 120

    /// 是否有被中断的对话（需要显示 UI）
    private var hasInterruption: Bool {
        viewModel.interruption != nil
    }

    public init(
        conversationIdProvider: @escaping () -> UUID?,
        backgroundColorProvider: @escaping () -> Color = { Color.clear }
    ) {
        self.conversationIdProvider = conversationIdProvider
        self.backgroundColorProvider = backgroundColorProvider
    }

    public var body: some View {
        VStack(spacing: 0) {
            if hasInterruption {
                headerView

                if !isCollapsed {
                    contentView
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(height: hasInterruption ? sidebarHeight : 0)
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(minWidth: hasInterruption ? 240 : 0, idealWidth: hasInterruption ? 320 : 0)
        .background {
            if hasInterruption {
                backgroundColorProvider()
                    .opacity(0.82)
            }
        }
        .overlay {
            if hasInterruption {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(colorForInterruption.opacity(0.16))
                        .frame(height: 1)
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(colorForInterruption.opacity(0.12))
                        .frame(height: 1)
                }
            }
        }
        .task(id: conversationIdProvider()) {
            viewModel.refresh(conversationID: conversationIdProvider())
        }
        .animation(.easeInOut(duration: 0.16), value: isCollapsed)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(LumiPluginLocalization.string("Conversation Recovery", bundle: .module))
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Label(titleForInterruption, systemImage: iconForInterruption)
                .font(.headline)
                .foregroundStyle(colorForInterruption)

            Spacer()

            Text(timeAgo)
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isCollapsed.toggle()
                }
            } label: {
                Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help(isCollapsed
                ? LumiPluginLocalization.string("Expand", bundle: .module)
                : LumiPluginLocalization.string("Collapse", bundle: .module)
            )
        }
        .padding(.horizontal, 12)
        .frame(height: Self.headerHeight)
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(descriptionForInterruption)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if viewModel.interruption?.kind != .awaitingUserResponse {
                    Button(action: {
                        Task {
                            await viewModel.recover()
                        }
                    }) {
                        Label("恢复对话", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button(action: {
                    viewModel.dismiss()
                }) {
                    Label("忽略", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
    }

    // MARK: - Computed Properties

    private var sidebarHeight: CGFloat {
        guard hasInterruption else { return 0 }
        return isCollapsed ? Self.headerHeight : Self.headerHeight + Self.contentHeight
    }

    private var timeAgo: String {
        guard let interruption = viewModel.interruption else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale.current
        return formatter.localizedString(for: interruption.interruptedAt, relativeTo: Date())
    }

    private var iconForInterruption: String {
        guard let kind = viewModel.interruption?.kind else { return "questionmark.circle" }
        switch kind {
        case .streamingInterrupted:
            return "wifi.slash"
        case .errorState:
            return "exclamationmark.triangle"
        case .toolExecutionIncomplete:
            return "wrench.and.screwdriver"
        case .awaitingUserResponse:
            return "person.fill.questionmark"
        case .turnNotCompleted:
            return "arrow.clockwise"
        }
    }

    private var colorForInterruption: Color {
        guard let kind = viewModel.interruption?.kind else { return .orange }
        switch kind {
        case .streamingInterrupted:
            return .orange
        case .errorState:
            return .red
        case .toolExecutionIncomplete:
            return .blue
        case .awaitingUserResponse:
            return .purple
        case .turnNotCompleted:
            return .yellow
        }
    }

    private var titleForInterruption: String {
        guard let kind = viewModel.interruption?.kind else { return "对话中断" }
        switch kind {
        case .streamingInterrupted:
            return "对话被中断"
        case .errorState:
            return "对话出错"
        case .toolExecutionIncomplete:
            return "工具未完成"
        case .awaitingUserResponse:
            return "等待回复"
        case .turnNotCompleted:
            return "对话未完成"
        }
    }

    private var descriptionForInterruption: String {
        guard let kind = viewModel.interruption?.kind else { return "" }
        switch kind {
        case .streamingInterrupted:
            return "流式生成被中断。点击恢复以继续对话，或忽略此提示。"
        case .errorState:
            return "对话遇到错误。点击恢复以重试，或忽略此提示。"
        case .toolExecutionIncomplete:
            return "工具执行未完成。点击恢复以继续，或忽略此提示。"
        case .awaitingUserResponse:
            return "对话正在等待您的选择。请在下方回答问题，或关闭此提示。"
        case .turnNotCompleted:
            return "对话未正常完成。点击恢复以继续，或忽略此提示。"
        }
    }
}
