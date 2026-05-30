import SwiftUI

/// 在 SwiftUI 创建首个默认主窗口后，按 `CoreWindowIDStore` 补开其余已持久化的主窗口。
///
/// 主 `WindowGroup` 已禁用系统场景恢复；此处是唯一的多窗口数量恢复入口。
struct CoreWindowIDRestorer: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                let openIds = Set(RootContainer.shared.windowManagerVM.windowContainers.map(\.id))
                for route in CoreWindowIDStore.consumeAdditionalWindowRoutes(excluding: openIds) {
                    NotificationCenter.postOpenWindowWithRoute(route: route)
                }
            }
    }
}

extension View {
    func restoreCoreWindowIDs() -> some View {
        modifier(CoreWindowIDRestorer())
    }
}
