import SwiftUI

public struct AppContextMenuRow: View {
    let title: LocalizedStringKey
    let systemImage: String?
    let role: ButtonRole?
    let action: () -> Void

    public init(_ title: LocalizedStringKey, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.role = nil
        self.action = action
    }

    public init(_ title: LocalizedStringKey, systemImage: String? = nil, role: ButtonRole, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }

    public var body: some View {
        Button(role: role, action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
    }
}
