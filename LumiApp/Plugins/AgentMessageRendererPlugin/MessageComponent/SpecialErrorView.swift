import MagicKit
import SwiftUI

/// 原始 HTTP 错误详情折叠视图
///
/// 在错误气泡底部以可折叠的形式展示原始的 HTTP 状态码和响应体，
/// 便于用户或开发者排查问题。
struct RawErrorDetailView: View {
    let rawDetail: String
    @EnvironmentObject private var projectVM: ProjectVM
    @EnvironmentObject private var themeVM: ThemeVM
    @State private var isExpanded = false

    private var zh: Bool {
        projectVM.languagePreference == .chinese
    }

    private var toggleText: String {
        isExpanded
            ? (zh ? "隐藏原始错误" : "Hide Raw Error")
            : (zh ? "显示原始错误" : "Show Raw Error")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                    Text(toggleText)
                        .font(AppUI.Typography.caption2)
                }
                .foregroundColor(AppUI.Color.semantic.textTertiary)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(rawDetail)
                        .font(AppUI.Typography.footnote.monospaced())
                        .foregroundColor(AppUI.Color.semantic.textTertiary)
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(themeVM.activeAppTheme.workspaceSecondaryTextColor().opacity(0.05))
                        )
                }
                .frame(maxHeight: 150)
            }
        }
    }
}

/// 特殊错误内容视图（包含图标、标题、描述和建议）
struct SpecialErrorContentView: View {
    let title: String
    let description: String
    let suggestion: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppUI.Typography.callout)
                .fontWeight(.semibold)
                .foregroundColor(AppUI.Color.semantic.textPrimary)

            if !description.isEmpty {
                Text(description)
                    .font(AppUI.Typography.caption1)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 显示建议操作
            if let suggestion = suggestion, !suggestion.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppUI.Color.semantic.warning)
                    Text(suggestion)
                        .font(AppUI.Typography.caption2)
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
        }
    }
}

/// 特殊错误视图（用于 API 请求失败、网络错误等预定义错误）
struct SpecialErrorView: View {
    let title: String
    let description: String
    let suggestion: String?
    let rawErrorDetail: String?

    @EnvironmentObject private var themeVM: ThemeVM

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                ErrorIconView(size: 16, weight: .medium)
                SpecialErrorContentView(
                    title: title,
                    description: description,
                    suggestion: suggestion
                )
            }

            // 底部：原始 HTTP 错误折叠区域
            if let rawErrorDetail, !rawErrorDetail.isEmpty {
                Divider()
                    .overlay(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.15))
                    .padding(.top, 2)

                RawErrorDetailView(rawDetail: rawErrorDetail)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

/// 默认错误视图（通用错误展示）
struct DefaultErrorView: View {
    let title: String
    let message: String
    let rawErrorDetail: String?

    @EnvironmentObject private var themeVM: ThemeVM

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !message.isEmpty {
                PlainTextMessageContentView(
                    content: message,
                    monospaced: false
                )
                .font(AppUI.Typography.caption1)
                .foregroundColor(AppUI.Color.semantic.textSecondary)
            }

            // 底部：原始 HTTP 错误折叠区域
            if let rawErrorDetail, !rawErrorDetail.isEmpty {
                Divider()
                    .overlay(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.15))

                RawErrorDetailView(rawDetail: rawErrorDetail)
            }
        }
    }
}
