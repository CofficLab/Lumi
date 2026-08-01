import Foundation
import SwiftUI

/// Projects 工具运行时桥接
///
/// 用于在 Agent 工具中访问 ProjectsViewModel。
enum RuntimeBridge {
    nonisolated(unsafe) static var viewModel: ProjectsViewModel?
    nonisolated(unsafe) static var syncCoordinator: ProjectsSyncCoordinator?
}
