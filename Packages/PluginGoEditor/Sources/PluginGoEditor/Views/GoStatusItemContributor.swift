import Foundation
import EditorService
import GoEditorCore
import SwiftUI

/// Go 状态栏贡献者
///
/// 在编辑器工具栏显示 Go 构建/测试状态指示器。
@MainActor
public final class GoStatusItemContributor: SuperEditorStatusItemContributor {
    public let id: String = "go.status"

    private let buildManager: GoBuildManager
    private let testManager: GoTestManager

    public init(buildManager: GoBuildManager, testManager: GoTestManager) {
        self.buildManager = buildManager
        self.testManager = testManager
    }

    public func provideStatusItems(state: EditorState) -> [EditorStatusItemSuggestion] {
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
                content: { state in
                    AnyView(GoStatusIndicatorView(
                        state: state,
                        buildManager: self.buildManager,
                        testManager: self.testManager,
                        env: GoEnvResolver.resolveSnapshot()
                    ))
                }
            )
        ]
    }
}

// MARK: - 状态指示器视图

private struct GoStatusIndicatorView: View {
    @ObservedObject var state: EditorState
    @ObservedObject var buildManager: GoBuildManager
    @ObservedObject var testManager: GoTestManager
    public let env: GoEnvResolver.Snapshot

    public var body: some View {
        HStack(spacing: 4) {
            switch displayState {
            case .idle:
                Image(systemName: "goforward")
                    .font(.system(size: 9))
                    .foregroundColor(idleColor)
                    .help(statusHelp)

            case .building:
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 10, height: 10)
                Text(String(localized: "Building", table: "GoEditor"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            case .testing:
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 10, height: 10)
                Text(String(localized: "Testing", table: "GoEditor"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            case .formatting:
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 10, height: 10)
                Text(String(localized: "Formatting", table: "GoEditor"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

            case .tidying:
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 10, height: 10)
                Text(String(localized: "Tidying", table: "GoEditor"))
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
                if buildManager.errorCount > 0 {
                    Text("\(buildManager.errorCount)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: "FF453A"))
                }
            }
        }
        .opacity(displayState == .idle ? 0.4 : 1.0)
    }

    private var idleColor: Color {
        env.goplsPath == nil
            ? Color(hex: "FF9F0A")
            : Color.adaptive(light: "6B6B7B", dark: "EBEBF5")
    }

    private var statusHelp: String {
        let lsp = env.goplsPath == nil ? "gopls missing" : "gopls ready"
        let formatter: String
        if env.goplsPath != nil {
            formatter = "formatter: gopls"
        } else if env.gofumptPath != nil {
            formatter = "formatter: gofumpt"
        } else if env.goPath != nil {
            formatter = "formatter: gofmt"
        } else {
            formatter = "formatter missing"
        }
        return "\(lsp), \(formatter)"
    }

    private var displayState: DisplayState {
        if testManager.state == .testing {
            return .testing
        }
        switch buildManager.state {
        case .idle:
            return .idle
        case .building:
            return .building
        case .formatting:
            return .formatting
        case .tidying:
            return .tidying
        case .success:
            return testManager.state == .success ? .success : .success
        case .failed:
            return .failed
        }
    }

    private enum DisplayState: Equatable {
        case idle
        case building
        case testing
        case formatting
        case tidying
        case success
        case failed
    }
}
