import AppKit
import EditorService
import LumiCoreKit
import SwiftUI

public struct EditorPackageDependencyRow: View {
    @EnvironmentObject private var editorContext: EditorContext

    public let dependency: EditorPackageDependency
    public let depth: Int

    @State private var isHovering = false

    public var body: some View {
        guard let theme = editorContext.activeChromeTheme else {
            return AnyView(Color.clear)
        }

        return AnyView(
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
            .onTapGesture(count: 2) { openLocation() }
            .help(dependency.location)
        )
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
        Button { openLocation() } label: {
            if dependency.kind == .local {
                Label(LumiPluginLocalization.string("Reveal in Finder", bundle: .module), systemImage: "finder")
            } else {
                Label(LumiPluginLocalization.string("Open Repository", bundle: .module), systemImage: "link")
            }
        }
        Button { copyLocation() } label: {
            Label(LumiPluginLocalization.string("Copy URL/path", bundle: .module), systemImage: "doc.on.doc")
        }
        Button { openInTerminal() } label: {
            Label(LumiPluginLocalization.string("Open in Terminal", bundle: .module), systemImage: "terminal")
        }
    }

    private func openLocation() {
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
