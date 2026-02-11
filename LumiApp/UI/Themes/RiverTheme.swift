import SwiftUI

struct RiverTheme: ThemeProtocol {
    let identifier = "river"
    let displayName = "河流青"
    let compactName = "河"
    let description = "清流涟漪，澄净通透"
    let iconName = "drop.fill"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "0EA5E9")
    }

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "0EA5E9"),
            secondary: SwiftUI.Color(hex: "22D3EE"),
            tertiary: SwiftUI.Color(hex: "10B981")
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "04111A"),
            medium: SwiftUI.Color(hex: "0A1E2B"),
            light: SwiftUI.Color(hex: "0F2A3A")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "0EA5E9").opacity(0.3),
            medium: SwiftUI.Color(hex: "22D3EE").opacity(0.5),
            intense: SwiftUI.Color(hex: "10B981").opacity(0.7)
        )
    }
}
