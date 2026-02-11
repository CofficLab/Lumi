import SwiftUI

struct AutumnTheme: ThemeProtocol {
    let identifier = "autumn"
    let displayName = "秋枫橙"
    let compactName = "秋"
    let description = "枫影微红，温润深远"
    let iconName = "wind"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "F97316")
    }

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "F97316"),
            secondary: SwiftUI.Color(hex: "DC2626"),
            tertiary: SwiftUI.Color(hex: "A16207")
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "160B05"),
            medium: SwiftUI.Color(hex: "2A1408"),
            light: SwiftUI.Color(hex: "3A1F0F")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "F97316").opacity(0.3),
            medium: SwiftUI.Color(hex: "DC2626").opacity(0.5),
            intense: SwiftUI.Color(hex: "A16207").opacity(0.7)
        )
    }
}
