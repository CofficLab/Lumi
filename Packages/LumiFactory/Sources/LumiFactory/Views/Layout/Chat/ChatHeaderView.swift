import LumiKernel
import LumiUI
import SwiftUI

struct ChatHeaderView: View {
    let kernel: LumiKernel

    // 只订阅 workspace 这一个 service：本视图不挂在 kernel 全局总线上，
    // project/conversations/settings 等无关服务变更不会触发这里刷新。
    // 父视图 ChatView 是条件 body，切换容器时本视图可能被重建，
    // 在 init 阶段同步绑定以避免 .task 异步绑定的时序竞争。
    @StateObject private var workspaceBox: ObservableWorkspaceBox

    init(kernel: LumiKernel) {
        self.kernel = kernel
        _workspaceBox = StateObject(wrappedValue: ObservableWorkspaceBox(service: kernel.workspace))
    }

    private var items: [ChatSectionHeaderItem] {
        workspaceBox.service?.allChatSectionHeaderItems ?? []
    }

    var body: some View {
        AppToolbarContainer(
            height: 40,
            backgroundStyle: .panel,
            padding: EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        ) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    item.makeView()
                }

                Spacer(minLength: 0)
            }
        }
        .borderBottom()
    }
}
