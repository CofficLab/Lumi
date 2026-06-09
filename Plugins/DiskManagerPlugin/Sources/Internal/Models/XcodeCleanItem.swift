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
        case .derivedData: return String(localized: "Derived Data", bundle: .module)
        case .archives: return String(localized: "Archives", bundle: .module)
        case .iOSDeviceSupport: return String(localized: "iOS Device Support", bundle: .module)
        case .watchOSDeviceSupport: return String(localized: "watchOS Device Support", bundle: .module)
        case .tvOSDeviceSupport: return String(localized: "tvOS Device Support", bundle: .module)
        case .simulatorCaches: return String(localized: "Simulator Caches", bundle: .module)
        case .logs: return String(localized: "Logs", bundle: .module)
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
        case .derivedData: return String(localized: "Intermediate files and indices from the build process, safe to delete.", bundle: .module)
        case .archives: return String(localized: "App packaging archive files.", bundle: .module)
        case .iOSDeviceSupport: return String(localized: "Symbol files generated when debugging connected devices.", bundle: .module)
        case .watchOSDeviceSupport: return String(localized: "Apple Watch debug symbol files.", bundle: .module)
        case .tvOSDeviceSupport: return String(localized: "Apple TV debug symbol files.", bundle: .module)
        case .simulatorCaches: return String(localized: "Simulator runtime cache.", bundle: .module)
        case .logs: return String(localized: "Old simulator logs and debug records.", bundle: .module)
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
