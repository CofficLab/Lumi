import LLMKit
import KernelLumi

private let rendererOrder = 305

enum HttpErrorRenderer {
    static let item = LumiMessageRendererItem(
        id: "aliyun-http-error",
        order: rendererOrder,
        canRender: { message in
            AliyunRenderKind.matchesOtherHttpError(message)
        },
        render: { message, _ in
            let statusCode = AliyunRenderKind.httpStatusCode(from: message.renderKind)
            HttpErrorView(message: message, statusCode: statusCode)
        }
    )
}