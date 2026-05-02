import Foundation
import SwiftUI
import MagicKit

/// Go 状态栏贡献者
///
/// 在编辑器工具栏显示 Go 构建/测试状态指示器。
@MainActor
final class GoStatusItemContributor: SuperEditorStatusItemContributor {
    let id: String = "go.status"

    private let buildManager: GoBuildManager

    init(buildManager: GoBuildManager) {
        self.buildManager = buildManager
    }

    func provideStatusItems(state: EditorState) -> [EditorStatusItemSuggestion] {
        [
            EditorStatusItemSuggestion(
                id: "go.status-indicator",
                order: 150,
                placement: .toolbarCenter,
                metadata: .init(
                    priority: 15,
                    dedupeKey: "go-status",
                    whenClause: .equals(.languageId, .string("go"))
                ),
                content: { _ in
                    AnyView(GoStatusIndicatorView(buildManager: self.buildManager))
                }
            )
        ]
    }
}

// MARK: - 状态指示器视图

private struct GoStatusIndicatorView: View {
    @ObservedObject var buildManager: GoBuildManager

    var body: some View {
        HStack(spacing: 4) {
            switch buildManager.state {
            case .idle:
                Image(systemName: "goforward")
                    .font(.system(size: 9))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)

            case .building:
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 10, height: 10)
                Text(String(localized: "Building", table: "GoEditor"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)

            case .testing:
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 10, height: 10)
                Text(String(localized: "Testing", table: "GoEditor"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)

            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundColor(AppUI.Color.semantic.success)

            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 9))
                    .foregroundColor(AppUI.Color.semantic.error)
                if buildManager.errorCount > 0 {
                    Text("\(buildManager.errorCount)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(AppUI.Color.semantic.error)
                }
            }
        }
        .opacity(buildManager.state == .idle ? 0.4 : 1.0)
    }
}
