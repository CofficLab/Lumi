import LumiCoreKit
import MessageRendererPlugin
import SwiftUI

/// 智谱 HTTP 错误视图（布局对齐 App 默认 ErrorMessage，正文展示原始 HTTP 信息）
struct HttpErrorView: View {
    let message: ChatMessage
    let statusCode: Int?
    @Binding var showRawMessage: Bool

    private var displayText: String {
        if let raw = message.rawErrorDetail, !raw.isEmpty {
            return raw
        }
        if let statusCode {
            return "HTTP \(statusCode)"
        }
        return ""
    }

    var body: some View {
        ErrorMessageLayout(message: message, showRawMessage: $showRawMessage) {
            DefaultErrorView(
                title: "",
                message: displayText,
                rawErrorDetail: nil
            )
        }
    }
}
