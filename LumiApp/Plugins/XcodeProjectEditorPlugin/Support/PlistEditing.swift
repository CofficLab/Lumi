import Foundation
import AppKit

/// Info.plist 和 .entitlements 编辑优化
enum PlistEditing {
    struct KnownEntry: Equatable {
        let key: String
        let description: String
        let valueSuggestions: [String]
    }

    struct KeyOccurrence: Equatable {
        let key: String
        let range: NSRange
        let line: Int
    }
    
    /// 常见的 Info.plist key 及其描述
    static let commonKeys: [String: String] = [
        "CFBundleName": "Bundle Name - 应用名称",
        "CFBundleDisplayName": "Display Name - 显示名称",
        "CFBundleIdentifier": "Bundle ID - 应用唯一标识",
        "CFBundleVersion": "Bundle Version - 构建版本号",
        "CFBundleShortVersionString": "Short Version - 营销版本号",
        "CFBundlePackageType": "Package Type - 包类型",
        "CFBundleSignature": "Bundle Signature - 签名",
        "LSMinimumSystemVersion": "Minimum System Version - 最低系统版本",
        "NSPrincipalClass": "Principal Class - 主类",
        "NSMainStoryboardFile": "Main Storyboard - 主 Storyboard",
        "UILaunchStoryboardName": "Launch Storyboard - 启动 Storyboard",
        "UIApplicationSceneManifest": "Scene Manifest - 场景配置",
        "UISupportedInterfaceOrientations": "Supported Orientations - 支持的方向",
        "UIRequiredDeviceCapabilities": "Required Capabilities - 所需设备能力",
        "NSAppTransportSecurity": "App Transport Security - 网络安全",
        "NSCameraUsageDescription": "Camera Usage - 相机使用说明",
        "NSPhotoLibraryUsageDescription": "Photo Library Usage - 照片库使用说明",
        "NSLocationWhenInUseUsageDescription": "Location Usage - 位置使用说明",
        "NSBluetoothPeripheralUsageDescription": "Bluetooth Usage - 蓝牙使用说明",
    ]
    
    /// 常见的 Entitlements key
    static let commonEntitlements: [String: String] = [
        "com.apple.security.application-groups": "App Groups - 应用组共享",
        "com.apple.developer.icloud-container-identifiers": "iCloud Containers - iCloud 容器",
        "com.apple.developer.associated-domains": "Associated Domains - 关联域名",
        "com.apple.developer.applesignin": "Sign in with Apple - Apple 登录",
        "com.apple.developer.networking.wifi-info": "WiFi Info - WiFi 信息",
        "com.apple.developer.usernotifications.communication": "Communication Notifications - 通讯通知",
        "com.apple.developer.team-identifier": "Team Identifier - 团队标识",
        "keychain-access-groups": "Keychain Access Groups - 钥匙串访问组",
        "com.apple.security.device.audio-input": "Audio Input - 音频输入",
        "com.apple.security.device.camera": "Camera - 相机",
    ]

    private static let plistEntries: [KnownEntry] = [
        .init(key: "CFBundleName", description: commonKeys["CFBundleName"] ?? "", valueSuggestions: ["$(PRODUCT_NAME)"]),
        .init(key: "CFBundleDisplayName", description: commonKeys["CFBundleDisplayName"] ?? "", valueSuggestions: ["$(PRODUCT_NAME)"]),
        .init(key: "CFBundleIdentifier", description: commonKeys["CFBundleIdentifier"] ?? "", valueSuggestions: ["$(PRODUCT_BUNDLE_IDENTIFIER)"]),
        .init(key: "CFBundleVersion", description: commonKeys["CFBundleVersion"] ?? "", valueSuggestions: ["1", "$(CURRENT_PROJECT_VERSION)"]),
        .init(key: "CFBundleShortVersionString", description: commonKeys["CFBundleShortVersionString"] ?? "", valueSuggestions: ["1.0", "$(MARKETING_VERSION)"]),
        .init(key: "LSMinimumSystemVersion", description: commonKeys["LSMinimumSystemVersion"] ?? "", valueSuggestions: ["13.0", "14.0", "15.0"]),
        .init(key: "NSCameraUsageDescription", description: commonKeys["NSCameraUsageDescription"] ?? "", valueSuggestions: ["This app requires camera access."]),
        .init(key: "NSPhotoLibraryUsageDescription", description: commonKeys["NSPhotoLibraryUsageDescription"] ?? "", valueSuggestions: ["This app requires photo library access."]),
        .init(key: "NSLocationWhenInUseUsageDescription", description: commonKeys["NSLocationWhenInUseUsageDescription"] ?? "", valueSuggestions: ["This app requires your location while in use."]),
        .init(key: "NSBluetoothPeripheralUsageDescription", description: commonKeys["NSBluetoothPeripheralUsageDescription"] ?? "", valueSuggestions: ["This app uses Bluetooth to connect to accessories."])
    ]

    private static let entitlementEntries: [KnownEntry] = [
        .init(key: "com.apple.security.application-groups", description: commonEntitlements["com.apple.security.application-groups"] ?? "", valueSuggestions: ["group.$(PRODUCT_BUNDLE_IDENTIFIER)"]),
        .init(key: "com.apple.developer.associated-domains", description: commonEntitlements["com.apple.developer.associated-domains"] ?? "", valueSuggestions: ["applinks:example.com"]),
        .init(key: "com.apple.developer.applesignin", description: commonEntitlements["com.apple.developer.applesignin"] ?? "", valueSuggestions: ["Default"]),
        .init(key: "keychain-access-groups", description: commonEntitlements["keychain-access-groups"] ?? "", valueSuggestions: ["$(AppIdentifierPrefix)$(CFBundleIdentifier)"]),
        .init(key: "com.apple.security.device.camera", description: commonEntitlements["com.apple.security.device.camera"] ?? "", valueSuggestions: ["true"])
    ]
    
    /// 验证 plist 内容
    static func validatePlist(_ content: String) -> [String] {
        var warnings: [String] = []
        
        // 检查是否包含常见但可能缺失的 key
        guard let data = content.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            warnings.append("无法解析为有效的 plist")
            return warnings
        }
        
        // 检查是否包含必要字段
        if plist["CFBundleIdentifier"] == nil {
            warnings.append("缺少 CFBundleIdentifier")
        }
        if plist["CFBundleVersion"] == nil {
            warnings.append("缺少 CFBundleVersion")
        }
        if plist["CFBundleShortVersionString"] == nil {
            warnings.append("缺少 CFBundleShortVersionString")
        }
        
        return warnings
    }
    
    /// 快速跳转到指定 key（在 XML 中定位）
    static func findKeyLocation(in content: String, key: String) -> NSRange? {
        let keyPattern = "<key>\\s*\(NSRegularExpression.escapedPattern(for: key))\\s*</key>"
        guard let regex = try? NSRegularExpression(pattern: keyPattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: content, range: NSRange(location: 0, length: content.utf16.count)) else {
            return nil
        }
        return match.range
    }

    static func supports(fileURL: URL) -> Bool {
        let ext = fileURL.pathExtension.lowercased()
        return ext == "plist" || ext == "entitlements"
    }

    static func hoverMarkdown(for key: String, fileURL: URL) -> String? {
        guard supports(fileURL: fileURL),
              let entry = entry(forKey: key, fileURL: fileURL) else {
            return nil
        }

        let values = entry.valueSuggestions.isEmpty
            ? ""
            : "\n\nSuggested values:\n" + entry.valueSuggestions.map { "- `\($0)`" }.joined(separator: "\n")
        return "### `\(entry.key)`\n\(entry.description)\(values)"
    }

    static func completionSuggestions(
        prefix: String,
        line: Int,
        character: Int,
        content: String,
        fileURL: URL
    ) -> [EditorCompletionSuggestion] {
        guard supports(fileURL: fileURL) else { return [] }
        let normalizedPrefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let entries = knownEntries(for: fileURL)
        let matchingKeys = entries.filter {
            normalizedPrefix.isEmpty || $0.key.lowercased().hasPrefix(normalizedPrefix)
        }

        let currentKey = currentKey(in: content, line: line, character: character)
        let matchingValues = currentKey
            .flatMap { entry(forKey: $0, fileURL: fileURL) }?
            .valueSuggestions
            .filter { normalizedPrefix.isEmpty || $0.lowercased().contains(normalizedPrefix) } ?? []

        let keySuggestions = matchingKeys.enumerated().map { index, entry in
            EditorCompletionSuggestion(
                label: entry.key,
                insertText: entry.key,
                detail: entry.description,
                priority: 220 - index
            )
        }

        let valueSuggestions = matchingValues.enumerated().map { index, value in
            EditorCompletionSuggestion(
                label: value,
                insertText: value,
                detail: currentKey.map { "Suggested value for \($0)" },
                priority: 260 - index
            )
        }

        return valueSuggestions + keySuggestions
    }

    static func currentKey(in content: String, line: Int, character: Int) -> String? {
        guard let offset = utf16Offset(in: content, line: line, character: character) else { return nil }
        let prefix = (content as NSString).substring(to: offset)
        let pattern = #"<key>\s*([^<]+?)\s*</key>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let matches = regex.matches(in: prefix, range: NSRange(location: 0, length: prefix.utf16.count))
        return matches.last.flatMap { match in
            guard let range = Range(match.range(at: 1), in: prefix) else { return nil }
            return String(prefix[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    static func keyOccurrences(in content: String) -> [KeyOccurrence] {
        let pattern = #"<key>\s*([^<]+?)\s*</key>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(location: 0, length: content.utf16.count)
        return regex.matches(in: content, range: range).compactMap { match in
            let keyRange = match.range(at: 1)
            guard let swiftRange = Range(keyRange, in: content) else { return nil }
            return KeyOccurrence(
                key: String(content[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines),
                range: keyRange,
                line: lineNumber(for: keyRange.location, in: content)
            )
        }
    }

    private static func knownEntries(for fileURL: URL) -> [KnownEntry] {
        fileURL.pathExtension.lowercased() == "entitlements" ? entitlementEntries : plistEntries
    }

    private static func entry(forKey key: String, fileURL: URL) -> KnownEntry? {
        knownEntries(for: fileURL).first { $0.key == key }
    }

    private static func utf16Offset(in content: String, line: Int, character: Int) -> Int? {
        guard line >= 0, character >= 0 else { return nil }
        var currentLine = 0
        var currentCharacter = 0
        var offset = 0

        for scalar in content.utf16 {
            if currentLine == line && currentCharacter == character {
                return offset
            }
            offset += 1
            if scalar == 10 {
                currentLine += 1
                currentCharacter = 0
            } else {
                currentCharacter += 1
            }
        }

        return currentLine == line ? min(offset, content.utf16.count) : nil
    }

    private static func lineNumber(for utf16Offset: Int, in content: String) -> Int {
        var line = 1
        var offset = 0
        for scalar in content.utf16 {
            if offset >= utf16Offset { break }
            if scalar == 10 { line += 1 }
            offset += 1
        }
        return line
    }
}
