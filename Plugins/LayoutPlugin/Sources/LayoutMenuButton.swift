import LumiCoreKit
import LumiUI
import SwiftUI

/// Layout menu for toggling the right ChatSection visibility.
public struct LayoutMenuButton: View {
    /// Borderless `Menu` labels ignore icon `foregroundStyle` on macOS and keep system primary.
    static let usesBorderlessMenuLabel = false

    @LumiTheme private var theme
    @State private var isPopoverPresented = false
    let layoutContext: LayoutControlContext

    public init(layoutContext: LayoutControlContext) {
        self.layoutContext = layoutContext
    }

    public var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            Image(systemName: "sidebar.leading")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Self.iconForegroundColor(theme: theme))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            Toggle(isOn: layoutContext.chatSectionVisible) {
                Label(
                    LumiPluginLocalization.string("Right Sidebar", bundle: .module),
                    systemImage: "rectangle.rightthird.inset.filled"
                )
            }
            .toggleStyle(.checkbox)
            .padding(12)
        }
        .frame(width: 22, height: 22)
        .fixedSize()
        .help(LumiPluginLocalization.string("Layout", bundle: .module))
    }

    static func iconForegroundColor(theme: any LumiUITheme) -> Color {
        theme.textPrimary
    }
}
