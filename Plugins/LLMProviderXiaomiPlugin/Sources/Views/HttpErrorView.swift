import LumiKernel
import LumiKernel
import LumiUI
import SwiftUI

/// HTTP 错误（403/其它状态码）或请求失败的渲染视图。
///
/// 不含 401（未授权复用 `ApiKeyMissingView` 配置界面）。展示状态码、错误摘要。
struct HttpErrorView: View {
    @LumiTheme private var theme
    private static let transportDetailsSeparator = "\n\n--- Request / Response Details ---\n"

    let message: LumiChatMessage
    let statusCode: Int?

    private var title: String {
        if let statusCode {
            return String(format: NSLocalizedString("Xiaomi HTTP %lld", bundle: .module, comment: ""), statusCode)
        }
        return NSLocalizedString("Xiaomi request failed", bundle: .module, comment: "")
    }

    private var displayText: String {
        let raw = ((message.rawErrorDetail?.isEmpty == false) ? message.rawErrorDetail : message.content) ?? ""
        var text = raw.components(separatedBy: Self.transportDetailsSeparator).first ?? raw

        if let code = statusCode {
            let prefix = "HTTP \(code) "
            if text.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
            }
        }
        return text
    }

    var body: some View {
        ErrorMessageLayout(message: message) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)

                if !displayText.isEmpty {
                    Text(displayText)
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                        .textSelection(.enabled)
                }
            }
        }
    }
}