import LumiKernel
import LumiUI
import SwiftUI

// MARK: - LoadingToolSectionView

struct LoadingToolSectionView: View {
    @LumiTheme private var theme

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text(verbatim: LumiPluginLocalization.string("查询结果中...", bundle: .module))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .toolSubtleCard()
    }
}

// MARK: - ToolFailureNoticeView

struct ToolFailureNoticeView: View {
    @LumiTheme private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(theme.error)

            Text(verbatim: LumiPluginLocalization.string("工具执行失败", bundle: .module))
                .font(.appCaptionEmphasized)
                .foregroundColor(theme.error)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .toolSubtleCard()
    }
}

// MARK: - ToolTextSectionView

struct ToolTextSectionView: View {
    @LumiTheme private var theme

    let content: String
    var isError = false

    var body: some View {
        AppCard(
            style: .subtle,
            padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        ) {
            ScrollView(.vertical, showsIndicators: true) {
                Text(content)
                    .font(.appMonoCaption)
                    .foregroundColor(isError ? theme.error : theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 360)
        }
    }
}

// MARK: - EmptyToolSectionView

struct EmptyToolSectionView: View {
    @LumiTheme private var theme

    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundColor(theme.textSecondary)

            Text(text)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .toolSubtleCard()
    }
}

// MARK: - ToolSubtleCardModifier

struct ToolSubtleCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        AppCard(
            style: .subtle,
            padding: EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        ) {
            content
        }
    }
}

extension View {
    func toolSubtleCard() -> some View {
        modifier(ToolSubtleCardModifier())
    }
}
