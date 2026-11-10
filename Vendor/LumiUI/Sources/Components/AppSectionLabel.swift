import SwiftUI

/// A lightweight, text-only section label.
///
/// Renders the canonical group-header styling used across the app —
/// `caption.weight(.semibold)` in the theme's secondary text color. Unlike
/// `GlassSectionHeader`, it has no icon and no subtitle, so it fits inline
/// above lists, sidebar groups, and panel sub-sections without taking vertical
/// space. Pass a custom `color` to override the default secondary tone.
public struct AppSectionLabel: View {
    @LumiTheme private var theme

    let title: Text
    let color: Color?

    public init(_ title: String, color: Color? = nil) {
        self.title = Text(title)
        self.color = color
    }

    public init(_ titleKey: LocalizedStringKey, color: Color? = nil) {
        self.title = Text(titleKey)
        self.color = color
    }

    public var body: some View {
        title
            .font(.caption.weight(.semibold))
            .foregroundStyle(color ?? theme.textSecondary)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        AppSectionLabel("App Versions")
        AppSectionLabel("General")
        AppSectionLabel("Platform", color: .blue)
    }
    .padding()
    .frame(width: 200, alignment: .leading)
    .background(Color.gray.opacity(0.15))
}
