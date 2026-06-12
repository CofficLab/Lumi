import LumiCoreKit
import LumiUI
import SwiftUI

/// Layout menu for toggling the right ChatSection visibility.
public struct LayoutMenuButton: View {
    /// `Menu` + `.borderlessButton` does not reliably inherit parent `foregroundStyle`.
    static let usesExplicitIconForeground = true

    @LumiTheme private var theme
    let layoutContext: LayoutControlContext

    public init(layoutContext: LayoutControlContext) {
        self.layoutContext = layoutContext
    }

    public var body: some View {
        Menu {
            Toggle(isOn: layoutContext.chatSectionVisible) {
                Label(
                    LumiPluginLocalization.string("Right Sidebar", bundle: .module),
                    systemImage: "rectangle.rightthird.inset.filled"
                )
            }
        } label: {
            Image(systemName: "sidebar.leading")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textPrimary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 22, height: 22)
        .fixedSize()
        .help(LumiPluginLocalization.string("Layout", bundle: .module))
    }
}
