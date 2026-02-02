import AppKit
import Foundation
import SwiftUI

/// 应用模型
struct AppModel: Identifiable, Hashable {
    let id: String = UUID().uuidString
    let bundleURL: URL
    let bundleName: String
    let bundleIdentifier: String?
    let version: String?
    let iconFileName: String?
    let icon: NSImage?
    var size: Int64 = 0

    var displayName: String {
        bundleName.isEmpty ? (bundleURL.deletingPathExtension().lastPathComponent) : bundleName
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    init(bundleURL: URL) {
        self.bundleURL = bundleURL

        let bundle = Bundle(url: bundleURL)
        self.bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundleURL.deletingPathExtension().lastPathComponent
        self.bundleIdentifier = bundle?.bundleIdentifier
        self.version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        
        let iconFile = bundle?.object(forInfoDictionaryKey: "CFBundleIconFile") as? String
        self.iconFileName = iconFile

        // 获取应用图标
        if let bundle = bundle,
           let iconFile = iconFile {
            let iconPath = bundle.bundleURL.appendingPathComponent("Contents/Resources/\(iconFile)")
            // 处理带扩展名和不带扩展名的情况
            let finalIconPath: URL
            if iconPath.pathExtension.isEmpty {
                finalIconPath = iconPath.appendingPathExtension("icns")
            } else {
                finalIconPath = iconPath
            }
            self.icon = NSImage(contentsOf: finalIconPath)
        } else {
            // 尝试从工作空间获取图标
            self.icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        }
    }
    
    /// 从缓存初始化
    init(bundleURL: URL, name: String, identifier: String?, version: String?, iconFileName: String?, size: Int64) {
        self.bundleURL = bundleURL
        self.bundleName = name
        self.bundleIdentifier = identifier
        self.version = version
        self.iconFileName = iconFileName
        self.size = size
        
        if let iconFile = iconFileName {
            let iconPath = bundleURL.appendingPathComponent("Contents/Resources/\(iconFile)")
            let finalIconPath: URL
            if iconPath.pathExtension.isEmpty {
                finalIconPath = iconPath.appendingPathExtension("icns")
            } else {
                finalIconPath = iconPath
            }
            self.icon = NSImage(contentsOf: finalIconPath)
        } else {
            self.icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleURL.path)
    }

    static func == (lhs: AppModel, rhs: AppModel) -> Bool {
        lhs.bundleURL.path == rhs.bundleURL.path
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(AppManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
