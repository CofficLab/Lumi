import AppKit
import MagicKit
import SwiftUI

struct EditorPackageDependencyRow: View {
    @EnvironmentObject private var themeVM: AppThemeVM

    let dependency: EditorPackageDependency
    let depth: Int

    @State private var isHovering = false

    var body: some View {
        let theme = themeVM.activeAppTheme

        HStack(spacing: 4) {
            Color.clear.frame(width: 12)

            Image(systemName: dependency.kind == .local ? "folder" : "shippingbox")
                .font(.system(size: 12))
                .foregroundColor(iconColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(dependency.displayName)
                    .font(.system(size: 11))
                    .foregroundColor(theme.workspaceTextColor())
                    .lineLimit(1)

                Text(dependency.subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(theme.workspaceSecondaryTextColor())
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if dependency.status != .resolved {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange.opacity(0.8))
                    .help(dependency.status.displayText)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .padding(.leading, CGFloat(depth) * 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovering ? theme.workspaceTextColor().opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu { contextMenuContent }
        .onTapGesture(count: 2) { revealInFinder() }
        .help(dependency.location)
    }

    private var iconColor: Color {
        switch dependency.status {
        case .resolved:
            return dependency.kind == .local ? .blue.opacity(0.75) : .purple.opacity(0.75)
        case .unresolved, .missing:
            return .orange.opacity(0.75)
        }
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        Button { revealInFinder() } label: {
            Label(String(localized: "Reveal in Finder", table: "EditorRailFileTree"), systemImage: "finder")
        }
        Button { copyLocation() } label: {
            Label(String(localized: "Copy URL/path", table: "EditorRailFileTree"), systemImage: "doc.on.doc")
        }
        Button { openInTerminal() } label: {
            Label(String(localized: "Open in Terminal", table: "EditorRailFileTree"), systemImage: "terminal")
        }
    }

    private func revealInFinder() {
        if dependency.kind == .local {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: dependency.location)])
        } else if let url = URL(string: dependency.location) {
            NSWorkspace.shared.open(url)
        }
    }

    private func copyLocation() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(dependency.location, forType: .string)
    }

    private func openInTerminal() {
        guard dependency.kind == .local else { return }
        EditorFileTreeService.openInTerminal(URL(fileURLWithPath: dependency.location))
    }
}
