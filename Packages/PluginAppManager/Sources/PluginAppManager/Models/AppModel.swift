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
        let rawBundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        self.bundleName = Self.sanitizedBundleName(rawBundleName, bundleURL: bundleURL)
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
        self.bundleName = Self.sanitizedBundleName(name, bundleURL: bundleURL)
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

    /// 校验字符串能否安全地作为单个路径 component 使用。
    /// 拒绝空值、`.`/`..` 以及包含分隔符或 NUL 的名称，避免拼接路径时逃逸出目标目录。
    static func isValidPathComponent(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != ".", trimmed != ".." else { return false }
        guard !value.contains("/"), !value.contains("\0") else { return false }
        return true
    }

    /// CFBundleName 来自应用自带的 Info.plist，不可直接信任；非法时回退到 .app 目录名。
    static func sanitizedBundleName(_ raw: String?, bundleURL: URL) -> String {
        let fallback = bundleURL.deletingPathExtension().lastPathComponent
        guard let raw, isValidPathComponent(raw) else { return fallback }
        return raw
    }

    static func == (lhs: AppModel, rhs: AppModel) -> Bool {
        lhs.bundleURL.path == rhs.bundleURL.path
    }
}

