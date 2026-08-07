import LumiKernel
import LumiUI
import SwiftUI

/// 聊天分区标题栏视图
///
/// 不订阅 workspace 服务的 `objectWillChange`（无需 `ObservableWorkspaceBox` 包装），
/// 改为「快照 + 事件刷新」：
/// - `init` 阶段读一次初值：启动注册贡献时不发通知，且父视图 ChatView 是条件 body，
///   切换容器时本视图可能被重建，同步读初值可避免 .task 异步绑定的时序竞争；
/// - 监听 `.workspaceContributionsDidChange`：任一 UI 贡献清单（含 chat section
///   header items）注册/注销/全量重建完成后由 workspace 服务广播，此处重新拉取。
struct ChatHeaderView: View {
    let kernel: LumiKernel

    @State private var items: [ChatSectionHeaderItem] = []

    init(kernel: LumiKernel) {
        self.kernel = kernel
        _items = State(initialValue: kernel.workspace?.allChatSectionHeaderItems ?? [])
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
        .onWorkspaceContributionsDidChange {
            items = kernel.workspace?.allChatSectionHeaderItems ?? []
        }
    }
}
