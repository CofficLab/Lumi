import SwiftUI

/// 应用启动时从磁盘恢复多窗口状态（全局只执行一次）。
struct WindowRestoreOverlay<Content: View>: View {
    let content: Content

    @EnvironmentObject private var windowManagerVM: WindowManagerVM

    var body: some View {
        content
            .onAppear {
                WindowPersistenceCoordinator.shared.restoreIfNeeded(
                    windowManagerVM: windowManagerVM,
                    openAdditionalWindow: { route in
                        NotificationCenter.default.post(
                            name: .openWindowWithRoute,
                            object: nil,
                            userInfo: ["route": route]
                        )
                    }
                )
            }
    }
}

#Preview("Window Restore Overlay") {
    WindowRestoreOverlay(content: Text("Content"))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .inRootView()
}
