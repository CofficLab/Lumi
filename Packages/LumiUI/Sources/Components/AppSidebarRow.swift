import SwiftUI

/// A generic, selectable sidebar navigation row with an optional trailing slot.
///
/// Use `AppSidebarRow` for the recurring "leading status glyph + title + trailing
/// status text/count/badge" layout found across sidebar navigation. The leading
/// icon, its color, the selection state, and the trailing content are all
/// configurable, while hover motion and the selected/hover backgrounds are
/// sourced from the Lumi theme tokens so every sidebar stays visually consistent.
public struct AppSidebarRow<Trailing: View>: View {
    @LumiTheme private var theme
    @LumiMotionPreferenceReader private var motionPreference

    let title: String
    let systemImage: String?
    let leadingColor: Color?
    let isSelected: Bool
    let action: (() -> Void)?
    let trailing: Trailing

    @State private var isHovered = false

    public init(
        title: String,
        systemImage: String? = nil,
        leadingColor: Color? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.systemImage = systemImage
        self.leadingColor = leadingColor
        self.isSelected = isSelected
        self.action = action
        self.trailing = trailing()
    }

    public init(
        title: String,
        systemImage: String? = nil,
        leadingColor: Color? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) where Trailing == EmptyView {
        self.title = title
        self.systemImage = systemImage
        self.leadingColor = leadingColor
        self.isSelected = isSelected
        self.action = action
        self.trailing = EmptyView()
    }

    public var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2)
                        .foregroundStyle(leadingColor ?? theme.textSecondary)
                        .frame(width: 14)
                }

                Text(title)
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                trailing
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
            .scaleEffect(isHovered && motionPreference.allowsMotion ? AppUI.Motion.rowHoverScale : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            AppUI.Motion.animate(AppUI.Motion.enabled(AppUI.Motion.hover, preference: motionPreference)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            theme.appListRowSelectedBackground
        } else if isHovered {
            theme.appListRowHoverBackground
        } else {
            Color.clear
        }
    }
}

#Preview {
    VStack(spacing: 4) {
        AppSidebarRow(
            title: LumiUILocalization.string("Account"),
            systemImage: "person.crop.circle",
            isSelected: true,
            action: {}
        )
        AppSidebarRow(
            title: LumiUILocalization.string("Apps"),
            systemImage: "square.grid.2x2",
            isSelected: false,
            action: {}
        )
        AppSidebarRow(
            title: "1.4.2",
            systemImage: "checkmark.circle.fill",
            leadingColor: .green,
            isSelected: false,
            action: {}
        ) {
            Text(LumiUILocalization.string("Ready"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    .frame(width: 240)
    .padding()
    .background(Color.gray.opacity(0.15))
}
