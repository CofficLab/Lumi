import Foundation
import SwiftUI
import LumiKernel

enum ToolCallResultVisualState: Equatable {
    case loading
    case failed
    case completed

    init(result: LumiToolResult?, isLoading: Bool) {
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
