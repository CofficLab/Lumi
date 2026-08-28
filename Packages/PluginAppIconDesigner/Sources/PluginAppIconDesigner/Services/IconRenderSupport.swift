import SwiftUI

extension Color {
    init(iconHex: String) {
        let trimmed = IconColorHex.normalized(iconHex).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        guard Scanner(string: trimmed).scanHexInt64(&value) else {
            self = .clear
            return
        }

        switch trimmed.count {
        case 8:
            self.init(
                .sRGB,
                red: Double((value >> 24) & 0xff) / 255,
                green: Double((value >> 16) & 0xff) / 255,
                blue: Double((value >> 8) & 0xff) / 255,
                opacity: Double(value & 0xff) / 255
            )
        case 6:
            self.init(
                .sRGB,
                red: Double((value >> 16) & 0xff) / 255,
                green: Double((value >> 8) & 0xff) / 255,
                blue: Double(value & 0xff) / 255,
                opacity: 1
            )
        default:
            self = .clear
        }
    }
}

extension UnitPoint {
    init(iconPoint: IconUnitPoint) {
        self.init(x: iconPoint.x, y: iconPoint.y)
    }
}

extension IconPaint {
    var hexValue: String {
        switch self {
        case .color(let value):
            return IconColorHex.normalized(value)
        case .linearGradient(let colors, _, _):
            return IconColorHex.normalized(colors.first ?? "#00000000")
        case .radialGradient(let colors, _, _, _):
            return IconColorHex.normalized(colors.first ?? "#00000000")
        }
    }
}
