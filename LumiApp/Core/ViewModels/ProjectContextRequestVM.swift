import Foundation
import SwiftUI

/// 仅保存“项目上下文需要更新”的意图状态。
/// - handler 执行复杂副作用
/// - RootView 监听并触发 handler
@MainActor
final class ProjectContextRequestVM: ObservableObject {
    @Published var request: ProjectContextRequest?
}

