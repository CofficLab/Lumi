import LumiKernel
import SwiftUI

/// 服务解析层 + 桥接层
///
/// `kernel.messageSend` 在 `MessageSenderPlugin.onReady` 才注册;为安全起见,
/// 这里做 optional 解包后再把 service 包进 `ObservableMessageSendingBox`,
/// 供内层 `@ObservedObject` 使用。
///
/// 桥接原理:`ObservableMessageSendingBox` 把 service 的 `objectWillChange`
/// 转发到自己的 publisher,这样内层 view 可以正常接收 `@Published` 更新。
struct AttachmentPreviewResolverView: View {
    @ObservedObject var kernel: LumiKernel
    @StateObject private var boxHolder = BoxHolder()

    var body: some View {
        if let messageSend = kernel.messageSender {
            // 在 messageSend 变化时重建 box(很少发生)
            let box = boxHolder.box(for: messageSend)
            AttachmentPreviewView(box: box)
        } else {
            EmptyView()
        }
    }
}

/// 持有当前 box;当 messageSend 实例变化时重建
@MainActor
private final class BoxHolder: ObservableObject {
    private(set) var box: ObservableMessageSendingBox?

    /// 取得当前 messageSend 对应的 box,必要时重建。
    ///
    /// 注意:此方法只在父 view 的 body 内被调用。新 box 会同步返回并传给
    /// `AttachmentPreviewView`,因此**不能**在此处触发 `objectWillChange.send()`
    /// —— 在 body 渲染期间发布更新会引发 "Publishing changes from within view
    /// updates" 警告。父 view 的重渲染由 `kernel`(`@ObservedObject`)驱动,
    /// 下次重渲染时通过 service 身份比较即可取到缓存的 box,无需本 holder 自行通知。
    func box(for messageSend: any MessageSending) -> ObservableMessageSendingBox {
        if let existing = box, existing.service === messageSend {
            return existing
        }
        let new = ObservableMessageSendingBox(service: messageSend)
        box = new
        return new
    }
}
