import SwiftUI

/// 主窗口根视图：用 `@StateObject` 固定 `WindowScope` 生命周期
///
/// `WindowGroup` 的 scene body 会在状态变化时反复求值；若在其中 `let scope = WindowScope(...)`，
/// 每次求值都会新建 scope，导致持久化恢复写入旧实例、UI 绑定新实例，从而再次弹出选项目界面。
struct MainWindowRootView: View {
    @StateObject private var scope: WindowScope

    init(route: LumiWindowRoute) {
        _scope = StateObject(
            wrappedValue: WindowScope(route: route, container: RootContainer.shared)
        )
    }

    var body: some View {
        ContentLayout(
            conversationId: scope.selectedConversationId,
            projectPath: scope.projectPath
        )
        .inRootView(scope: scope)
    }
}
