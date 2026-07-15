import LumiCoreKit
import LumiUI
import SwiftUI

/// Layout menu for toggling layout visibility.
public struct LayoutMenuButton: View {
    /// Borderless `Menu` labels ignore icon `foregroundStyle` on macOS and keep system primary.
    static let usesBorderlessMenuLabel = false

    @LumiTheme private var theme
    @ObservedObject private var lumiCore: LumiCore
    @State private var isPopoverPresented = false

    // layoutState 从 lumiCore 获取
    private var layoutState: LumiLayoutState {
        lumiCore.layoutState ?? LumiLayoutState()
    }

    public init(lumiCore: LumiCore) {
        self._lumiCore = ObservedObject(wrappedValue: lumiCore)
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
            VStack(alignment: .leading, spacing: 0) {
                LayoutPopoverToggle(
                    isOn: Binding(
                        get: { layoutState.chatSectionVisible },
                        set: { layoutState.chatSectionVisible = $0 }
                    ),
                    icon: "rectangle.rightthird.inset.filled",
                    title: LumiPluginLocalization.string("Right Sidebar", bundle: .module)
                )

                Divider()
                    .padding(.vertical, 4)

                LayoutPopoverToggle(
                    isOn: Binding(get: { layoutState.bottomPanelVisible }, set: { layoutState.bottomPanelVisible = $0 }),
                    icon: "rectangle.inset.filled",
                    title: LumiPluginLocalization.string("Bottom Panel", bundle: .module)
                )
            }
            .padding(12)
            .frame(minWidth: 180, alignment: .leading)
            .appSurface(style: .popover, cornerRadius: 8, borderColor: theme.divider)
            .appThemedAppearance()
            .background {
                ThemeWindowAppearanceBridge()
            }
        }
        .frame(width: 22, height: 22)
        .fixedSize()
        .help(LumiPluginLocalization.string("Layout", bundle: .module))
    }

    static func iconForegroundColor(theme: any LumiUITheme) -> Color {
        theme.textPrimary
    }
}

private struct LayoutPopoverToggle: View {
    @LumiTheme private var theme
    @Binding var isOn: Bool
    let icon: String
    let title: String

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LayoutMenuButton.popoverLabelForegroundColor(theme: theme))

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(LayoutMenuButton.popoverLabelForegroundColor(theme: theme))
            }
        }
        .toggleStyle(.checkbox)
    }
}

extension LayoutMenuButton {
    static func popoverLabelForegroundColor(theme: any LumiUITheme) -> Color {
        theme.textPrimary
    }

    static func popoverBackgroundColor(theme: any LumiUITheme) -> Color {
        theme.appPopoverBackground
    }
}
