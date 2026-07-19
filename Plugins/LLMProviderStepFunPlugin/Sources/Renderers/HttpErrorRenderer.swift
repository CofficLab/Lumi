import LumiKernel
import LLMKit
import LumiKernel
import LumiUI
import SwiftUI

enum HttpErrorRenderer {
    static let item = LumiMessageRendererItem(
        id: "stepfun-http-error",
        order: StepFunPlugin.info.order + 230,
        canRender: { message in
            StepFunRenderKind.matchesOtherHttpError(message)
        },
        render: { message, showRawMessage in
            let statusCode = StepFunRenderKind.httpStatusCode(from: message.renderKind)
            HttpErrorView(message: message, statusCode: statusCode, showRawMessage: showRawMessage)
        }
    )
}

struct HttpErrorView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    let statusCode: Int?
    @Binding var showRawMessage: Bool

    var body: some View {
        ErrorMessageLayout(message: message, showRawMessage: $showRawMessage) {
            VStack(alignment: .leading, spacing: 10) {
                Text(LumiPluginLocalization.string("StepFun API error", bundle: .module))
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)

                if let statusCode {
                    Text(LumiPluginLocalization.string("HTTP \(statusCode)", bundle: .module))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }

                Text(LumiPluginLocalization.string("The StepFun API returned an error. Please try again later.", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }
        }
    }
}
