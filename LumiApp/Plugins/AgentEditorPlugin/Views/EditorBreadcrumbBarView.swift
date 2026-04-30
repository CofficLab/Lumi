import SwiftUI
import MagicKit

struct EditorBreadcrumbBarView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    let cursorLine: Int
    let cursorColumn: Int
    let activeGroupIndex: Int?
    let groupCount: Int
    let minimapPolicy: EditorMinimapPolicy
    let isOutlinePresented: Bool
    let onToggleOutline: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            BreadcrumbPathView()
                .layoutPriority(1)

            Spacer(minLength: 0)

            if let activeGroupIndex, groupCount > 1 {
                statusChip("G\(activeGroupIndex + 1)/\(groupCount)", systemName: "square.split.2x1")
            }

            Button(action: onToggleOutline) {
                statusChip("Outline", systemName: "list.bullet.indent", isActive: isOutlinePresented)
            }
            .buttonStyle(.plain)

            if minimapPolicy.isForcedHidden {
                statusChip(minimapPolicy.statusTitle, systemName: "rectangle.split.1x2")
            }

            statusChip("Ln \(max(cursorLine, 1)), Col \(max(cursorColumn, 1))", systemName: "location")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(themeManager.activeAppTheme.workspaceTertiaryTextColor().opacity(0.04))
    }

    private func statusChip(_ title: String, systemName: String, isActive: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .semibold))
            Text(title)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(isActive ? AppUI.Color.semantic.primary : themeManager.activeAppTheme.workspaceSecondaryTextColor())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            isActive
                ? AppUI.Color.semantic.primary.opacity(0.10)
                : themeManager.activeAppTheme.workspaceTextColor().opacity(0.05)
        )
        .clipShape(Capsule())
    }
}
