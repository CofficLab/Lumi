import Foundation
import SwiftUI
import MagicKit

/// Go 面板贡献者
///
/// 注册构建输出面板和测试结果面板到编辑器底部面板区域。
@MainActor
final class GoPanelContributor: SuperEditorPanelContributor {
    let id: String = "go.panels"

    /// 面板标签页
    private enum Tab: String, CaseIterable {
        case build
        case test
    }

    private let buildManager: GoBuildManager

    /// 当前激活的面板 nil（由面板系统管理）
    @State private var activeTab: Tab = .build

    init(buildManager: GoBuildManager) {
        self.buildManager = buildManager
    }

    func providePanels(state: EditorState) -> [EditorPanelSuggestion] {
        // 仅对 Go 文件显示面板
        guard state.detectedLanguage?.tsName == "go" else { return [] }
        guard buildManager.state != .idle || !buildManager.issues.isEmpty || !buildManager.testEvents.isEmpty || buildManager.state == .building || buildManager.state == .testing else {
            return []
        }

        return [
            EditorPanelSuggestion(
                id: "go.build-output",
                title: String(localized: "Build", table: "GoEditor"),
                systemImage: "hammer",
                placement: .bottom,
                order: 500,
                isPresented: { [weak self] state in
                    guard let self else { return false }
                    return self.shouldShow(for: state)
                },
                onDismiss: { _ in },
                content: { [weak self] state in
                    guard let self else { return AnyView(EmptyView()) }
                    let projectRoot = GoProjectDetector.findProjectRoot(from: state.currentFileURL ?? URL(fileURLWithPath: ""))
                    return AnyView(
                        GoBuildOutputView(
                            buildManager: self.buildManager,
                            projectRoot: projectRoot
                        )
                    )
                }
            ),
            EditorPanelSuggestion(
                id: "go.test-results",
                title: String(localized: "Tests", table: "GoEditor"),
                systemImage: "testtube.2",
                placement: .bottom,
                order: 510,
                isPresented: { [weak self] state in
                    guard let self else { return false }
                    return self.shouldShowTest(for: state)
                },
                onDismiss: { _ in },
                content: { [weak self] _ in
                    guard let self else { return AnyView(EmptyView()) }
                    return AnyView(
                        GoTestResultView(buildManager: self.buildManager)
                    )
                }
            )
        ]
    }

    // MARK: - Visibility

    private func shouldShow(for state: EditorState) -> Bool {
        guard state.detectedLanguage?.tsName == "go" else { return false }
        return buildManager.state == .building
            || buildManager.state == .success
            || buildManager.state == .failed
            || !buildManager.issues.isEmpty
    }

    private func shouldShowTest(for state: EditorState) -> Bool {
        guard state.detectedLanguage?.tsName == "go" else { return false }
        return buildManager.state == .testing
            || !buildManager.testEvents.isEmpty
    }
}
