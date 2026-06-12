import SwiftUI

extension Notification.Name {
    public static let applicationDidBecomeActive = Notification.Name("applicationDidBecomeActive")
    public static let currentProjectDidChange = Notification.Name("CurrentProjectDidChange")
}

extension View {
    public func onApplicationDidBecomeActive(perform action: @escaping () -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .applicationDidBecomeActive)) { _ in
            action()
        }
    }

    public func onCurrentProjectDidChange(perform action: @escaping (String, String) -> Void) -> some View {
        onReceive(
            NotificationCenter.default
                .publisher(for: .currentProjectDidChange)
                .receive(on: RunLoop.main)
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let name = userInfo["projectName"] as? String,
                  let path = userInfo["projectPath"] as? String else {
                return
            }
            action(name, path)
        }
    }
}
