import Foundation
import SwiftUI

/// Projects 工具运行时桥接
///
/// 用于在 Agent 工具中访问 ProjectsViewModel。
enum ProjectsToolRuntimeBridge {
    nonisolated(unsafe) static var viewModel: ProjectsViewModel?
}