import LumiCoreKit
import LumiUI
import SwiftUI

enum RequestFailedRenderer {
    static let item = LumiMessageRendererItem(
        id: "stepfun-request-failed",
        order: info.order + 240,
        canRender: { message in
            StepFunRenderKind.matches(renderKind: StepFunRenderKind.requestFailed, message: message)
        },
        render: { message, showRawMessage in
            RequestFailedView(message: message, showRawMessage: showRawMessage)
        }
    )
}

struct RequestFailedView: View {
    @LumiTheme private var theme

    let message: LumiChatMessage
    @Binding var showRawMessage: Bool

    var body: some View {
        ErrorMessageLayout(message: message, showRawMessage: $showRawMessage) {
            VStack(alignment: .leading, spacing: 10) {
                Text(LumiPluginLocalization.string("StepFun request failed", bundle: .module))
                    .font(.appCallout)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimary)

                Text(LumiPluginLocalization.string("Failed to connect to StepFun API. Please check your network connection and try again.", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)
            }
        }
    }
}
