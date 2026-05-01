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
/// EditorVM 只持有一个 `EditorService` 实例，所有编辑器能力通过它访问。
///
/// ## 使用方式
///
/// ```swift
/// @EnvironmentObject private var editorVM: EditorVM
///
/// editorVM.service.currentFileURL
/// editorVM.service.openFile(at: url)
/// editorVM.service.performCommand(id: "builtin.find")
/// editorVM.service.splitRight()
/// ```
@MainActor
final class EditorVM: ObservableObject {

    /// 编辑器统一服务（对外门面）
    let service: EditorService

    // MARK: - Initialization

    init(service: EditorService) {
        self.service = service
    }
}
