import AppKit
import Foundation
import SwiftUI

/// 应用模型
struct AppModel: Identifiable, Hashable, @unchecked Sendable {
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

    // 某些应用的图标文件可能存在问题，强制使用系统图标
    private static let forceSystemIconBundleIDs: Set<String> = [
        "com.apple.iBooksX"
    ]

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
        var loadedIcon: NSImage?
        
        let shouldForceSystemIcon = bundleIdentifier.map { Self.forceSystemIconBundleIDs.contains($0) } ?? false
        
        if !shouldForceSystemIcon,
           let bundle = bundle,
           let iconFile = iconFile {
            let iconPath = bundle.bundleURL.appendingPathComponent("Contents/Resources/\(iconFile)")
            // 处理带扩展名和不带扩展名的情况
            let finalIconPath: URL
            if iconPath.pathExtension.isEmpty {
                finalIconPath = iconPath.appendingPathExtension("icns")
            } else {
                finalIconPath = iconPath
            }
            loadedIcon = NSImage(contentsOf: finalIconPath)
        }
        
        if let icon = loadedIcon, icon.isValid, icon.size.width > 0 {
            self.icon = icon
        } else {
            // 尝试从工作空间获取图标
            let icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
            // 显式设置大小以获取更高清晰度的图标（如果可用）
            icon.size = NSSize(width: 64, height: 64)
            self.icon = icon
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
        
        var loadedIcon: NSImage?
        
        let shouldForceSystemIcon = identifier.map { Self.forceSystemIconBundleIDs.contains($0) } ?? false
        
        if !shouldForceSystemIcon, let iconFile = iconFileName {
            let iconPath = bundleURL.appendingPathComponent("Contents/Resources/\(iconFile)")
            let finalIconPath: URL
            if iconPath.pathExtension.isEmpty {
                finalIconPath = iconPath.appendingPathExtension("icns")
            } else {
                finalIconPath = iconPath
            }
            loadedIcon = NSImage(contentsOf: finalIconPath)
        }
        
        if let icon = loadedIcon, icon.isValid, icon.size.width > 0 {
            self.icon = icon
        } else {
            let icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
            icon.size = NSSize(width: 64, height: 64)
            self.icon = icon
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
