import CoreGraphics
import LumiUI
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// V5（ChatGPT 风格）消息列表视图。
///
/// 与 V1–V3 的差异：V5 把消息按**轮次**组织，而不是按行组织。
/// 一轮对话里的用户气泡、助手正文与工作历史被包进同一个 `ChatGPTTurnView`，
/// 轮尾操作因此只出现一次，且挂在轮尾助手正文上。
///
/// ## 为什么仍然用 SwiftUI `List`
///
/// 与其它档位相同的理由：`LazyVStack` 在富文本长列表下会触发
/// AttributeGraph 活锁（主线程 100% CPU），普通 `VStack` 会 eager
/// materialize 全部行。macOS 上 `List` 底层是 `NSTableView`，有真正的 cell 复用。
///
/// - Important: 禁止把这里改成 `ScrollView + LazyVStack` 或 eager `VStack`。
struct ChatGPTListView: View {
    let services: MessageListServices
    @ObservedObject private var viewModel: ChatGPTListViewModel

    @LumiTheme private var theme

    /// 聊天容器宽度（用于响应式列宽）。
    @State private var containerWidth: CGFloat = 0

    init(services: MessageListServices, viewModel: ChatGPTListViewModel) {
        self.services = services
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            // Important: GeometryReader 只用来读**聊天容器宽度**，
            // 不读取任何底部锚点 preference —— 偏好反馈会形成活锁。
            GeometryReader { proxy in
                messageList
                    .onAppear { containerWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, newValue in
                        containerWidth = newValue
                    }
            }
        }
        .task {
            await viewModel.activateCurrentConversation()
        }
    }

    // MARK: - List

    private var messageList: some View {
        List {
            loadEarlierButton

            ForEach(projection.turns) { turn in
                ChatGPTTurnView(
                    services: services,
                    turn: turn,
                    verbosity: viewModel.verbosity,
                    containerWidth: containerWidth
                )
                .id(turn.id)
            }
        }
        .id(viewModel.selectedConversationID)
        .accessibilityIdentifier(ChatGPTAccessibilityIdentifiers.listContainer)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        // 让 Markdown 代码块使用 HorizontalScrollView，不捕获垂直滚动
        .environment(\.preferOuterScroll, true)
    }

    // MARK: - 加载更早

    @ViewBuilder
    private var loadEarlierButton: some View {
        if viewModel.hasEarlierMessages {
            HStack {
                Spacer()
                if viewModel.isLoadingEarlier {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        Task { await viewModel.loadEarlier() }
                    } label: {
                        Text(pluginLocalization.string("加载更早的消息"))
                            .font(.appCaption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(theme.textSecondary)
                    .accessibilityIdentifier(ChatGPTAccessibilityIdentifiers.loadEarlierButton)
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - 投影

    /// 当前投影出的轮次。
    private var projection: ChatGPTTurnProjection {
        viewModel.turnProjection
    }
}
