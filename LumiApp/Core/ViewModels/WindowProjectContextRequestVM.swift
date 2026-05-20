import Foundation
import SwiftUI

/// 仅保存“项目上下文需要更新”的意图状态。
/// - handler 执行复杂副作用
///
/// ## 初始化规则
///
/// 由 `WindowScope` 持有，通过 `.environmentObject()` 注入。nRootView 监听其 `request` 变化处理项目上下文请求。
/// - RootView 监听并触发 handler
///
/// ## 初始化规则
///
/// 由 `WindowScope` 持有并通过 `.environmentObject()` 注入。
/// RootView 监听其 `request` 变化处理项目上下文请求。
@MainActor
final class WindowProjectContextRequestVM: ObservableObject {
    @Published var request: ProjectContextRequest?
}

