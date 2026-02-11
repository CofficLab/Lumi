import SwiftUI

struct OrchardTheme: ThemeProtocol {
    let identifier = "orchard"
    let displayName = "果园红"
    let compactName = "果"
    let description = "果香微甜，鲜亮活力"
    let iconName = "apple.logo"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "F43F5E")
    }

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "F43F5E"),
            secondary: SwiftUI.Color(hex: "F97316"),
            tertiary: SwiftUI.Color(hex: "84CC16")
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "14070B"),
            medium: SwiftUI.Color(hex: "1F0D12"),
            light: SwiftUI.Color(hex: "2B1118")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "F43F5E").opacity(0.3),
            medium: SwiftUI.Color(hex: "F97316").opacity(0.5),
            intense: SwiftUI.Color(hex: "84CC16").opacity(0.7)
        )
    }
}
