import SwiftUI

struct MountainTheme: ThemeProtocol {
    let identifier = "mountain"
    let displayName = "山岚灰"
    let compactName = "山"
    let description = "石色沉稳，松影清远"
    let iconName = "mountain.2.fill"

    var iconColor: SwiftUI.Color {
        SwiftUI.Color(hex: "64748B")
    }

    func accentColors() -> (primary: SwiftUI.Color, secondary: SwiftUI.Color, tertiary: SwiftUI.Color) {
        (
            primary: SwiftUI.Color(hex: "64748B"),
            secondary: SwiftUI.Color(hex: "94A3B8"),
            tertiary: SwiftUI.Color(hex: "22C55E")
        )
    }

    func atmosphereColors() -> (deep: SwiftUI.Color, medium: SwiftUI.Color, light: SwiftUI.Color) {
        (
            deep: SwiftUI.Color(hex: "0A0C10"),
            medium: SwiftUI.Color(hex: "12161D"),
            light: SwiftUI.Color(hex: "1C2230")
        )
    }

    func glowColors() -> (subtle: SwiftUI.Color, medium: SwiftUI.Color, intense: SwiftUI.Color) {
        (
            subtle: SwiftUI.Color(hex: "64748B").opacity(0.3),
            medium: SwiftUI.Color(hex: "94A3B8").opacity(0.5),
            intense: SwiftUI.Color(hex: "22C55E").opacity(0.7)
        )
    }
}
