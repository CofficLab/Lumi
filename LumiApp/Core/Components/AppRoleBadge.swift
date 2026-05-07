import SwiftUI

/// 角色/状态徽标组件。
struct AppRoleBadge: View {
    enum Style {
        case neutral
        case accent
    }

    let title: String
    let style: Style

    init(_ title: String, style: Style = .neutral) {
        self.title = title
        self.style = style
    }

    var body: some View {
        AppTag(
            title,
            style: style == .accent ? .accent : .subtle
        )
    }
}

#Preview {
    HStack(spacing: 8) {
        AppRoleBadge("Tool Output")
        AppRoleBadge("Assistant", style: .accent)
    }
    .padding()
    .inRootView()
}
