import SwiftUI
import LumiUI

/// 可折叠的消息内容容器
///
/// 当内容超过指定行数时自动折叠，用户点击可展开/收起。
/// 用于处理超长用户消息和助手回复的显示优化。
struct CollapsibleMessageContent<Content: View>: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    @LumiMotionPreferenceReader private var motionPreference

    /// 消息原始内容（用于字符数估算）
    let rawContent: String

    /// 折叠时显示的最大行数
    let collapsedLineLimit: Int

    /// 消息内容
    @ViewBuilder let content: Content

    /// 内容字符数阈值：超过此值判定为需要折叠
    private var needsCollapse: Bool {
        rawContent.count > characterThreshold
    }

    /// 根据 collapsedLineLimit 计算字符阈值（每行约 60 字符）
    private var characterThreshold: Int {
        collapsedLineLimit * 60
    }

    /// 是否已展开
    @State private var isExpanded = false

    init(
        rawContent: String,
        collapsedLineLimit: Int = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.rawContent = rawContent
        self.collapsedLineLimit = collapsedLineLimit
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            contentGroup

            if needsCollapse {
                toggleButton
            }
        }
    }

    // MARK: - 子视图

    private var contentGroup: some View {
        Group {
            if isExpanded || !needsCollapse {
                content
            } else {
                content
                    .lineLimit(collapsedLineLimit)
            }
        }
        .animation(
            LumiMotion.enabled(LumiMotion.disclosure, preference: motionPreference),
            value: isExpanded
        )
    }

    private var toggleButton: some View {
        Button {
            withAnimation(LumiMotion.enabled(LumiMotion.disclosure, preference: motionPreference)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                Text(
                    isExpanded
                        ? String(localized: "Show Less", table: "CoreMessageRenderer")
                        : String(localized: "Show More", table: "CoreMessageRenderer")
                )
                .font(.appCaption)
            }
            .foregroundColor(theme.primary)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }
}

// MARK: - 预览

#Preview("Short Content") {
    CollapsibleMessageContent(
        rawContent: "Short message",
        collapsedLineLimit: 5
    ) {
        Text("This is a short message that should not be collapsed.")
            .font(.appBody)
    }
    .padding()
    .frame(width: 400)
}

#Preview("Long Content - Collapsed") {
    CollapsibleMessageContent(
        rawContent: String(repeating: "This is a very long message. ", count: 50),
        collapsedLineLimit: 5
    ) {
        Text(String(repeating: "This is a very long message. ", count: 50))
            .font(.appBody)
    }
    .padding()
    .frame(width: 400)
}
