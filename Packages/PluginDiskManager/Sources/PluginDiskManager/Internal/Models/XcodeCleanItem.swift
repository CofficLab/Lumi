import Foundation

public enum XcodeCleanCategory: String, CaseIterable, Identifiable, Sendable {
    case derivedData = "Derived Data"
    case archives = "Archives"
    case iOSDeviceSupport = "iOS Device Support"
    case watchOSDeviceSupport = "watchOS Device Support"
    case tvOSDeviceSupport = "tvOS Device Support"
    case simulatorCaches = "Simulator Caches"
    case logs = "Logs"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .derivedData: return pluginLocalization.string("Derived Data")
        case .archives: return pluginLocalization.string("Archives")
        case .iOSDeviceSupport: return pluginLocalization.string("iOS Device Support")
        case .watchOSDeviceSupport: return pluginLocalization.string("watchOS Device Support")
        case .tvOSDeviceSupport: return pluginLocalization.string("tvOS Device Support")
        case .simulatorCaches: return pluginLocalization.string("Simulator Caches")
        case .logs: return pluginLocalization.string("Logs")
        }
    }

    public var iconName: String {
        switch self {
        case .derivedData: return "hammer.fill"
        case .archives: return "archivebox.fill"
        case .iOSDeviceSupport: return "iphone"
        case .watchOSDeviceSupport: return "applewatch"
        case .tvOSDeviceSupport: return "tv"
        case .simulatorCaches: return "laptopcomputer"
        case .logs: return "doc.text.fill"
        }
    }

    public var description: String {
        switch self {
        case .derivedData: return pluginLocalization.string("Intermediate files and indices from the build process, safe to delete.")
        case .archives: return pluginLocalization.string("App packaging archive files.")
        case .iOSDeviceSupport: return pluginLocalization.string("Symbol files generated when debugging connected devices.")
        case .watchOSDeviceSupport: return pluginLocalization.string("Apple Watch debug symbol files.")
        case .tvOSDeviceSupport: return pluginLocalization.string("Apple TV debug symbol files.")
        case .simulatorCaches: return pluginLocalization.string("Simulator runtime cache.")
        case .logs: return pluginLocalization.string("Old simulator logs and debug records.")
        }
    }
}

public struct XcodeCleanItem: Identifiable, Equatable, Sendable {
    public let id = UUID()
    public let name: String
    public let path: URL
    public let size: Int64
    public let category: XcodeCleanCategory
    public let modificationDate: Date
    public var isSelected: Bool = false
    public var version: String?

    public init(name: String, path: URL, size: Int64, category: XcodeCleanCategory, modificationDate: Date, isSelected: Bool = false, version: String? = nil) {
        self.name = name
        self.path = path
        self.size = size
        self.category = category
        self.modificationDate = modificationDate
        self.isSelected = isSelected
        self.version = version
    }
}

/// 单个分类的预聚合快照（#1222）：随 ViewModel 的 itemsByCategory 变更单遍重算，
/// 分类头直接读取，避免每次 body 求值重新 filter/reduce 整个分类数组。
public struct XcodeCategorySummary: Equatable, Sendable {
    public var size: Int64
    public var selectedSize: Int64
    public var selectedCount: Int
    public var totalCount: Int

    public init(size: Int64, selectedSize: Int64, selectedCount: Int, totalCount: Int) {
        self.size = size
        self.selectedSize = selectedSize
        self.selectedCount = selectedCount
        self.totalCount = totalCount
    }
}
