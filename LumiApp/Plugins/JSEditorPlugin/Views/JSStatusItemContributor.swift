import Foundation
import SwiftUI
import MagicKit

@MainActor
final class JSStatusItemContributor: SuperEditorStatusItemContributor {
    let id = "js.status"

    private let taskManager: JSTaskManager

    init(taskManager: JSTaskManager) {
        self.taskManager = taskManager
    }

    func provideStatusItems(state: EditorState) -> [EditorStatusItemSuggestion] {
        [
            EditorStatusItemSuggestion(
                id: "js.status-indicator",
                order: 151,
                placement: .toolbarCenter,
                metadata: .init(
                    priority: 15,
                    dedupeKey: "js-status",
                    whenClause: .any([
                        .equals(.languageId, .string("javascript")),
                        .equals(.languageId, .string("typescript")),
                    ])
                ),
                content: { _ in
                    AnyView(JSStatusIndicatorView(taskManager: self.taskManager))
                }
            )
        ]
    }
}

private struct JSStatusIndicatorView: View {
    @ObservedObject var taskManager: JSTaskManager

    var body: some View {
        HStack(spacing: 4) {
            switch taskManager.state {
            case .idle:
                Image(systemName: "curlybraces")
                    .font(.system(size: 9))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            case .running, .building, .testing, .linting, .formatting:
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 10, height: 10)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: "30D158"))
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: "FF453A"))
                if taskManager.errorCount > 0 {
                    Text("\(taskManager.errorCount)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: "FF453A"))
                }
            }
        }
        .opacity(taskManager.state == .idle ? 0.4 : 1.0)
    }

    private var label: String {
        switch taskManager.state {
        case .building: return String(localized: "Building", table: "JSEditor")
        case .testing: return String(localized: "Testing", table: "JSEditor")
        case .linting: return String(localized: "Linting", table: "JSEditor")
        case .formatting: return String(localized: "Formatting", table: "JSEditor")
        default: return String(localized: "Running", table: "JSEditor")
        }
    }
}
