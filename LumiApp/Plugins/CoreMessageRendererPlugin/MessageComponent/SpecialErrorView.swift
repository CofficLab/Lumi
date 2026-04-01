import MagicKit
import SwiftUI

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
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

/// 默认错误视图（通用错误展示）
struct DefaultErrorView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                ErrorIconView(size: 16, weight: .medium)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppUI.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(AppUI.Color.semantic.textPrimary)

                    if !message.isEmpty {
                        PlainTextMessageContentView(
                            content: message,
                            monospaced: false
                        )
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                    }
                }
            }
        }
    }
}
