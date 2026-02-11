import SwiftUI

struct SpringTheme: ThemeProtocol {
    let identifier = "spring"
    let displayName = "春芽绿"
    let compactName = "春"
    let description = "春芽初醒，清新柔和"
    let iconName = "leaf.fill"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "7CCF7A")
    }

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "7CCF7A"),
            secondary: SwiftUI.Color(hex: "F9A8D4"),
            tertiary: SwiftUI.Color(hex: "60A5FA")
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "07110A"),
            medium: SwiftUI.Color(hex: "0D1A10"),
            light: SwiftUI.Color(hex: "13251A")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "7CCF7A").opacity(0.3),
            medium: SwiftUI.Color(hex: "F9A8D4").opacity(0.5),
            intense: SwiftUI.Color(hex: "60A5FA").opacity(0.7)
        )
    }
}
