import Combine
import EditorService
import Foundation
import SwiftUI

/// 编辑器 ViewModel
///
/// 作为插件视图与内核 Editor 服务之间的桥梁，通过 SwiftUI 环境注入。
/// 在 `RootViewContainer` 中初始化，插件视图通过 `@EnvironmentObject` 访问。
@MainActor
final class WindowEditorVM: ObservableObject {

    /// 编辑器统一服务（对外门面）
    let service: EditorService

    /// 内部订阅令牌
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(service: EditorService) {
        self.service = service

        service.sessionObjectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        service.state.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Theme Sync

    /// 由外层插件（ThemeStatusBarPlugin）调用，将 AppThemeVM 当前主题同步到编辑器。
    ///
    /// 解决 AppThemeVM 初始化时发出的通知在 EditorState 注册监听之前已发出的时序问题。
    func syncInitialEditorTheme(_ editorThemeId: String) {
        service.syncInitialThemeFromExternal(editorThemeId)
    }

    func cleanupForTeardown() {
        cancellables.removeAll()
        service.cleanupForTeardown()
    }
}
