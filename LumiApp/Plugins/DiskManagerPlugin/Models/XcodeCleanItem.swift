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
        case .derivedData: return "Intermediate files and indices from the build process, safe to delete."
        case .archives: return "App packaging archive files."
        case .iOSDeviceSupport: return "Symbol files generated when debugging connected devices."
        case .watchOSDeviceSupport: return "Apple Watch debug symbol files."
        case .tvOSDeviceSupport: return "Apple TV debug symbol files."
        case .simulatorCaches: return "Simulator runtime cache."
        case .logs: return "Old simulator logs and debug records."
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
