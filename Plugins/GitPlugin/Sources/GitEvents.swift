import SwiftUI

extension Notification.Name {
    public static let applicationDidBecomeActive = Notification.Name("applicationDidBecomeActive")
}

extension View {
    public func onApplicationDidBecomeActive(perform action: @escaping () -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .applicationDidBecomeActive)) { _ in
            action()
        }
    }
}
