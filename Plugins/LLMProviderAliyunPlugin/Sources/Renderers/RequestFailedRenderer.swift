import LLMKit
import LumiCoreMessage
import LumiKernel
import LumiLLMProviderSupport
import SwiftUI

private let rendererOrder = 305

enum RequestFailedRenderer {
    static let item = LumiMessageRendererItem(
        id: "aliyun-request-failed",
        order: rendererOrder,
        canRender: { message in
            AliyunRenderKind.matches(renderKind: AliyunRenderKind.requestFailed, message: message)
        },
        render: { message, showRawMessage in
            HttpErrorView(message: message, statusCode: nil, showRawMessage: showRawMessage)
        }
    )
}
