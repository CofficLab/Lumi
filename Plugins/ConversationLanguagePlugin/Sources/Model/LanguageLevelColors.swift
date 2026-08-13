import KernelLumi
import SwiftUI

extension LumiConversationLanguage {
    var foregroundColor: Color {
        switch self {
        case .chinese:
            Color.blue
        case .english:
            Color.purple
        }
    }

    var backgroundColor: Color {
        foregroundColor.opacity(0.22)
    }
}
