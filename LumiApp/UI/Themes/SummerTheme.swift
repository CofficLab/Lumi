import SwiftUI

struct SummerTheme: ThemeProtocol {
    let identifier = "summer"
    let displayName = "盛夏蓝"
    let compactName = "夏"
    let description = "炽阳海风，清澈明朗"
    let iconName = "sun.max.fill"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "38BDF8")
    }

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "38BDF8"),
            secondary: SwiftUI.Color(hex: "FACC15"),
            tertiary: SwiftUI.Color(hex: "34D399")
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "041018"),
            medium: SwiftUI.Color(hex: "082030"),
            light: SwiftUI.Color(hex: "0F2F3F")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "38BDF8").opacity(0.3),
            medium: SwiftUI.Color(hex: "FACC15").opacity(0.5),
            intense: SwiftUI.Color(hex: "34D399").opacity(0.7)
        )
    }
}
