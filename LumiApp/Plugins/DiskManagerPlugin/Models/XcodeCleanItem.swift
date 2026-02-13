import Foundation
import AppKit

enum XcodeCleanCategory: String, CaseIterable, Identifiable {
    case derivedData = "Derived Data"
    case archives = "Archives"
    case iOSDeviceSupport = "iOS Device Support"
    case watchOSDeviceSupport = "watchOS Device Support"
    case tvOSDeviceSupport = "tvOS Device Support"
    case simulatorCaches = "Simulator Caches"
    case logs = "Logs"
    // case documentation = "Documentation Cache" // Optional
    
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .derivedData: return String(localized: "Derived Data", table: "DiskManager")
        case .archives: return String(localized: "Archives", table: "DiskManager")
        case .iOSDeviceSupport: return String(localized: "iOS Device Support", table: "DiskManager")
        case .watchOSDeviceSupport: return String(localized: "watchOS Device Support", table: "DiskManager")
        case .tvOSDeviceSupport: return String(localized: "tvOS Device Support", table: "DiskManager")
        case .simulatorCaches: return String(localized: "Simulator Caches", table: "DiskManager")
        case .logs: return String(localized: "Logs", table: "DiskManager")
        }
    }
    
    var iconName: String {
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
    
    var description: String {
        switch self {
        case .derivedData: return String(localized: "Intermediate files and indices from the build process, safe to delete.", table: "DiskManager")
        case .archives: return String(localized: "App packaging archive files.", table: "DiskManager")
        case .iOSDeviceSupport: return String(localized: "Symbol files generated when debugging connected devices.", table: "DiskManager")
        case .watchOSDeviceSupport: return String(localized: "Apple Watch debug symbol files.", table: "DiskManager")
        case .tvOSDeviceSupport: return String(localized: "Apple TV debug symbol files.", table: "DiskManager")
        case .simulatorCaches: return String(localized: "Simulator runtime cache.", table: "DiskManager")
        case .logs: return String(localized: "Old simulator logs and debug records.", table: "DiskManager")
        }
    }
}

struct XcodeCleanItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: URL
    let size: Int64
    let category: XcodeCleanCategory
    let modificationDate: Date
    var isSelected: Bool = false
    
    // Additional info for sorting or display, e.g., version number for DeviceSupport
    var version: String?
}
