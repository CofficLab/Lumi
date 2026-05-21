import SwiftUI

/// Opens the remaining persisted main windows after SwiftUI creates the
/// first default window.
struct CoreWindowIDRestorer: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content
            .onAppear {
                for route in CoreWindowIDStore.consumeAdditionalWindowRoutes() {
                    openWindow(id: AppConfig.mainWindowID, value: route)
                }
            }
    }
}

extension View {
    func restoreCoreWindowIDs() -> some View {
        modifier(CoreWindowIDRestorer())
    }
}
