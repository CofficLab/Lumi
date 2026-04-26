import SwiftUI

/// 右侧栏视图：始终显示 Header + 消息列表 + 输入区
struct RightColumn: View {
    @EnvironmentObject var pluginProvider: PluginVM

    var body: some View {
        VStack(spacing: 0) {
            rightHeaderContent()

            GlassDivider()

            rightMiddleContent()

            GlassDivider()

            rightBottomContent()
        }
        .frame(maxHeight: .infinity)
        .frame(maxWidth: .infinity)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func rightHeaderContent() -> some View {
        let leadingView = pluginProvider.getRightHeaderLeadingView()
        let trailingItems = pluginProvider.getRightHeaderTrailingItems()

        HeaderView(leadingView: leadingView, trailingItems: trailingItems)
            .frame(minHeight: AppConfig.headerHeight)
            .zIndex(100)
    }

    @ViewBuilder
    private func rightMiddleContent() -> some View {
        let middleViews = pluginProvider.getRightMiddleViews()
        Group {
            if middleViews.isEmpty {
                AgentDefaultDetailView()
            } else {
                VStack(spacing: 0) {
                    ForEach(middleViews.indices, id: \.self) { index in
                        middleViews[index]
                            .id("right_middle_\(index)")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rightBottomContent() -> some View {
        let bottomViews = pluginProvider.getRightBottomViews()
        Group {
            if bottomViews.isEmpty {
                AgentDefaultDetailView()
            } else {
                VStack(spacing: 0) {
                    ForEach(bottomViews.indices, id: \.self) { index in
                        bottomViews[index]
                            .id("right_bottom_\(index)")
                    }
                }
            }
        }
    }
}

// MARK: - Header (inline)

private struct HeaderView: View {
    let leadingView: AnyView?
    let trailingItems: [AnyView]

    private let iconSize: CGFloat = 14

    var body: some View {
        HStack(spacing: 0) {
            if let leading = leadingView {
                leading
            } else {
                defaultLeadingView
            }

            Spacer()

            if !trailingItems.isEmpty {
                HStack(spacing: 12) {
                    ForEach(trailingItems.indices, id: \.self) { index in
                        trailingItems[index]
                            .id("header_trailing_\(index)")
                    }
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private var defaultLeadingView: some View {
        HStack(spacing: 8) {
            Image(systemName: "hammer.fill")
                .font(.system(size: iconSize))
                .foregroundColor(.accentColor)
                .padding(4)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(Circle())
            Text("Lumi")
                .font(AppUI.Typography.body)
                .fontWeight(.medium)
                .foregroundColor(AppUI.Color.semantic.textPrimary)
        }
    }
}
