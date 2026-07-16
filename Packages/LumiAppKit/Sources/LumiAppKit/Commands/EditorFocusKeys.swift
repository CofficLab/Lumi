import EditorService
import SwiftUI

/// 当前活跃窗口编辑器服务的 FocusedValueKey。
///
/// 用于让菜单命令（`Commands`）在不依赖 `@EnvironmentObject` 的情况下，
/// 拿到当前活跃窗口的 `EditorService`，从而实现焦点无关的快捷键（如 ⌘S 保存）。
struct ActiveEditorServiceKey: FocusedValueKey {
    typealias Value = EditorService
}

extension FocusedValues {
    /// 当前活跃窗口的编辑器服务（窗口内编辑器获得焦点时可用）。
    var activeEditorService: EditorService? {
        get { self[ActiveEditorServiceKey.self] }
        set { self[ActiveEditorServiceKey.self] = newValue }
    }
}
