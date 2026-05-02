import Combine
import Foundation
import SwiftUI

/// 编辑器 ViewModel
///
/// 作为插件视图与内核 Editor 服务之间的桥梁，通过 SwiftUI 环境注入。
/// 在 `RootViewContainer` 中初始化，插件视图通过 `@EnvironmentObject` 访问。
///
/// ## 架构说明
///
/// EditorVM 持有一个 `EditorService` 实例，所有编辑器能力通过它访问。
/// 同时订阅 service 内部 `sessionStore` 的变化通知并转发，
/// 确保所有通过 `@EnvironmentObject` 观察 EditorVM 的视图（如 Tab 栏）
/// 都能在 session/tab 变更时自动刷新，而不依赖 `selectedFileURL` 间接驱动。
///
/// ## 使用方式
///
/// ```swift
/// @EnvironmentObject private var editorVM: EditorVM
///
/// editorVM.service.currentFileURL
/// editorVM.service.openFile(at: url)
/// editorVM.service.performCommand(id: "builtin.find")
/// ```
@MainActor
final class EditorVM: ObservableObject {

    /// 编辑器统一服务（对外门面）
    let service: EditorService

    /// 内部订阅令牌
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(service: EditorService) {
        self.service = service

        // 将 sessionStore 的 objectWillChange 转发到 EditorVM，
        // 使依赖 @EnvironmentObject editorVM 的视图能感知 tabs/session 的增删改。
        service.sessionStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }
}
