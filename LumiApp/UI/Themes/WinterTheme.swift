import SwiftUI

struct WinterTheme: ThemeProtocol {
    let identifier = "winter"
    let displayName = "霜冬白"
    let compactName = "冬"
    let description = "霜雪凝光，清冷静谧"
    let iconName = "snowflake"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "60A5FA")
    }

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "60A5FA"),
            secondary: SwiftUI.Color(hex: "E0F2FE"),
            tertiary: SwiftUI.Color(hex: "A5B4FC")
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "060B16"),
            medium: SwiftUI.Color(hex: "0D1424"),
            light: SwiftUI.Color(hex: "16203A")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "60A5FA").opacity(0.3),
            medium: SwiftUI.Color(hex: "E0F2FE").opacity(0.5),
            intense: SwiftUI.Color(hex: "A5B4FC").opacity(0.7)
        )
    }
}
