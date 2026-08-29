import Foundation
import Combine

/// 磁盘清理类型（侧边栏 / 主视图切换用）。
///
/// 取代原先 `DiskManagerView` 里基于 `selectedViewMode: Int` 的切换方式，
/// 让侧边栏 rail 和主视图共用一个明确的语义枚举。
public enum DiskCleanupCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case largeFiles
    case directoryTree
    case cacheCleaner
    case xcodeCleaner
    case projectCleaner

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .largeFiles:     return PluginDiskManagerLocalization.string("Large Files")
        case .directoryTree:  return PluginDiskManagerLocalization.string("Directory Analysis")
        case .cacheCleaner:   return PluginDiskManagerLocalization.string("System Cleanup")
        case .xcodeCleaner:   return PluginDiskManagerLocalization.string("Xcode Cleanup")
        case .projectCleaner: return PluginDiskManagerLocalization.string("Project Cleanup")
        }
    }

    public var systemImage: String {
        switch self {
        case .largeFiles:     return "doc.text"
        case .directoryTree:  return "folder"
        case .cacheCleaner:   return "gear"
        case .xcodeCleaner:   return "hammer"
        case .projectCleaner: return "scissors"
        }
    }
}

/// 跨 DiskManager 视图共享的选中状态。
///
/// 由 ``DiskCleanupCategorySidebar``（rail view）和 ``DiskManagerView``（主视图）
/// 共享同一个实例，确保切换器在哪一侧改动都会同步到另一侧。
@MainActor
public final class DiskCleanupCategoryStore: ObservableObject {
    @Published public private(set) var selected: DiskCleanupCategory

    public init(initial: DiskCleanupCategory = .largeFiles) {
        self.selected = initial
    }

    public func select(_ category: DiskCleanupCategory) {
        guard selected != category else { return }
        selected = category
    }
}