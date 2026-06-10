import LumiCoreKit
import SwiftUI

/// Layout menu for toggling the right ChatSection visibility.
public struct LayoutMenuButton: View {
    let layoutContext: LayoutControlContext

    public init(layoutContext: LayoutControlContext) {
        self.layoutContext = layoutContext
    }

    public var body: some View {
        Menu {
            Toggle(isOn: layoutContext.chatSectionVisible) {
                Label(
                    String(localized: "Right Sidebar", bundle: .module),
                    systemImage: "rectangle.rightthird.inset.filled"
                )
            }
        } label: {
            Image(systemName: "sidebar.leading")
                .font(.system(size: 11, weight: .medium))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 22, height: 22)
        .fixedSize()
        .help(String(localized: "Layout", bundle: .module))
    }
}
