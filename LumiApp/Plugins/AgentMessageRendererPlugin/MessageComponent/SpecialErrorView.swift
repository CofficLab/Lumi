import LumiUI
import SwiftUI

/// 原始 HTTP 错误详情折叠视图
///
/// 在错误气泡底部以可折叠的形式展示原始的 HTTP 状态码和响应体，
/// 便于用户或开发者排查问题。
struct RawErrorDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let rawDetail: String
    @LumiMotionPreferenceReader private var motionPreference
    @EnvironmentObject private var projectVM: WindowProjectVM
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
                LumiMotion.animate(LumiMotion.enabled(LumiMotion.disclosure, preference: motionPreference)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.appMicroEmphasized)
                    Text(toggleText)
                        .font(.appMicro)
                }
                .foregroundColor(theme.textTertiary)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(rawDetail)
                        .font(.appMonoCaption)
                        .foregroundColor(theme.textTertiary)
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Color.clear
                                .appSurface(style: .subtle, cornerRadius: 6)
                        )
                }
                .frame(maxHeight: 150)
                .appDisclosureContentTransition(preference: motionPreference)
            }
        }
        .animation(LumiMotion.enabled(LumiMotion.disclosure, preference: motionPreference), value: isExpanded)
    }
}

/// 特殊错误内容视图（包含图标、标题、描述和建议）
struct SpecialErrorContentView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let title: String
    let description: String
    let suggestion: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.appCallout)
                .fontWeight(.semibold)
                .foregroundColor(theme.textPrimary)

            if !description.isEmpty {
                Text(description)
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 显示建议操作
            if let suggestion = suggestion, !suggestion.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.appMicro)
                        .foregroundColor(theme.warning)
                    Text(suggestion)
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 4)
            }
        }
    }
}

/// 特殊错误视图（用于 API 请求失败、网络错误等预定义错误）
struct SpecialErrorView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let title: String
    let description: String
    let suggestion: String?
    let rawErrorDetail: String?

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
                    .overlay(theme.divider)
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
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let title: String
    let message: String
    let rawErrorDetail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !message.isEmpty {
                PlainTextMessageContentView(
                    content: message,
                    monospaced: false
                )
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
            }

            // 底部：原始 HTTP 错误折叠区域
            if let rawErrorDetail, !rawErrorDetail.isEmpty {
                Divider()
                    .overlay(theme.divider)

                RawErrorDetailView(rawDetail: rawErrorDetail)
            }
        }
    }
}
