import AgentToolKit
import KernelCore
import LocalizationKit
import LumiUI
import MarkdownKit
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageSender
import ProviderToolManager
import Foundation
import SwiftUI

enum ToolCallResultVisualState: Equatable {
    case loading
    case failed
    case completed

    init(result: MessageToolResult?, isLoading: Bool) {
        if isLoading {
            self = .loading
        } else if result?.isError == true {
            self = .failed
        } else {
            self = .completed
        }
    }

    var systemImage: String {
        switch self {
        case .loading: "hourglass"
        case .failed: "exclamationmark.triangle.fill"
        case .completed: "doc.text.magnifyingglass"
        }
    }

    var isFailure: Bool {
        self == .failed
    }
}
