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
    // case documentation = "Documentation Cache" // 可选
    
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
        case .derivedData: return "构建过程中的中间文件和索引，可安全删除。"
        case .archives: return "应用打包归档文件。"
        case .iOSDeviceSupport: return "连接设备调试时生成的符号文件。"
        case .watchOSDeviceSupport: return "Apple Watch 调试符号文件。"
        case .tvOSDeviceSupport: return "Apple TV 调试符号文件。"
        case .simulatorCaches: return "模拟器运行时缓存。"
        case .logs: return "旧的模拟器日志和调试记录。"
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
    
    // 用于辅助排序或显示的额外信息，例如 DeviceSupport 的版本号
    var version: String?
}
