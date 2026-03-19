import AppKit
import SwiftUI

struct ErrorRecoveryBanner: View {
    @EnvironmentObject private var errorStateViewModel: ErrorStateVM

    var body: some View {
        if let error = errorStateViewModel.userFacingError {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: iconName(for: error.category))
                        .foregroundStyle(.red)
                    Text(error.title)
                        .font(.headline)
                    Spacer()
                    Button("清除") {
                        errorStateViewModel.clear()
                    }
                    .buttonStyle(.plain)
                }

                Text(error.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(error.recoverySuggestions.enumerated()), id: \.offset) { index, tip in
                        Text("\(index + 1). \(tip)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    Button("反馈问题") {
                        openFeedbackIssue(with: error)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("复制错误信息") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(error.message, forType: .string)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.red.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("错误提示")
            .accessibilityHint("包含错误原因、恢复建议和反馈入口")
        }
    }

    private func iconName(for category: UserFacingError.Category) -> String {
        switch category {
        case .network:
            return "wifi.exclamationmark"
        case .auth:
            return "key.fill"
        case .permission:
            return "lock.shield"
        case .rateLimit:
            return "speedometer"
        case .service:
            return "server.rack"
        case .unknown:
            return "exclamationmark.triangle.fill"
        }
    }

    private func openFeedbackIssue(with error: UserFacingError) {
        let issueTitle = "[Error Feedback] \(error.title)"
        let issueBody = """
        ## 问题描述
        请描述你触发这个问题时的操作步骤。

        ## 错误信息
        \(error.message)

        ## 错误分类
        \(error.category.rawValue)

        ## 已尝试的恢复步骤
        - [ ] 检查网络/配置
        - [ ] 重新发送请求
        - [ ] 重启应用后重试
        """

        let encodedTitle = issueTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = issueBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://github.com/CofficLab/Lumi/issues/new?title=\(encodedTitle)&body=\(encodedBody)"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
