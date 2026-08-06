import LumiKernel
import SwiftUI

extension LumiResponseVerbosity {
    var foregroundColor: Color {
        switch self {
        case .brief:
            Color.cyan
        case .standard:
            Color.primary.opacity(0.75)
        case .detailed:
            .purple
        }
    }

    var backgroundColor: Color {
        switch self {
        case .brief:
            Color.cyan.opacity(0.22)
        case .standard:
            Color.primary.opacity(0.12)
        case .detailed:
            Color.purple.opacity(0.22)
        }
    }
}
