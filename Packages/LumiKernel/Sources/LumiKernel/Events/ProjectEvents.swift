import Foundation
import SwiftUI

// MARK: - Notification Names

extension Notification.Name {
    public static let projectListDidChange = Notification.Name("ProjectListDidChange")
    public static let currentProjectDidChange = Notification.Name("CurrentProjectDidChange")
    public static let currentProjectPathDidChange = Notification.Name("CurrentProjectPathDidChange")
}

// MARK: - NotificationCenter Extensions

extension NotificationCenter {
    public static func postProjectListDidChange() {
        NotificationCenter.default.post(
            name: .projectListDidChange,
            object: nil,
            userInfo: nil
        )
    }

    public static func postCurrentProjectDidChange(project: ProjectEntry) {
        NotificationCenter.default.post(
            name: .currentProjectDidChange,
            object: nil,
            userInfo: ["project": project]
        )
    }

    public static func postCurrentProjectPathDidChange(path: String) {
        NotificationCenter.default.post(
            name: .currentProjectPathDidChange,
            object: nil,
            userInfo: ["path": path]
        )
    }
}

// MARK: - SwiftUI View Helpers

public extension View {
    func onCurrentProjectDidChange(perform action: @escaping (ProjectEntry) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .currentProjectDidChange)) { notification in
            guard let project = notification.userInfo?["project"] as? ProjectEntry else { return }
            action(project)
        }
    }
}
