import SwiftUI

/// 在 SwiftUI 创建首个默认主窗口后，按 `CoreWindowIDStore` 补开其余已持久化的主窗口。
///
/// 主 `WindowGroup` 已禁用系统场景恢复；此处是唯一的多窗口数量恢复入口。
struct CoreWindowIDRestorer: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    let windowId: UUID

    func body(content: Content) -> some View {
        content
            .onOpenWindowWithRoute { route in
                guard shouldHandleOpenWindowRequest else { return }
                openRoute(route)
            }
            .onAppear {
                let openIds = Set(RootContainer.shared.windowManagerVM.windowContainers.map(\.id))
                for route in CoreWindowIDStore.consumeAdditionalWindowRoutes(excluding: openIds) {
                    openRoute(route)
                }
            }
    }

    private func openRoute(_ route: LumiWindowRoute) {
        openWindow(id: AppConfig.mainWindowID, value: route)
    }

    private var shouldHandleOpenWindowRequest: Bool {
        let windowManager = RootContainer.shared.windowManagerVM
        guard let activeWindowId = windowManager.activeWindowId else {
            return windowManager.windowContainers.first?.id == windowId
        }
        return activeWindowId == windowId
    }
}

extension View {
    func restoreCoreWindowIDs(windowId: UUID) -> some View {
        modifier(CoreWindowIDRestorer(windowId: windowId))
    }
}
