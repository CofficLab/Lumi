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
    static var commonKeys: [String: String] {
        [
            "CFBundleName": String(localized: "Bundle Name - Application name", table: "EditorXcodePlugin"),
            "CFBundleDisplayName": String(localized: "Display Name - Shown on Home screen", table: "EditorXcodePlugin"),
            "CFBundleIdentifier": String(localized: "Bundle ID - Unique app identifier", table: "EditorXcodePlugin"),
            "CFBundleVersion": String(localized: "Bundle Version - Build version number", table: "EditorXcodePlugin"),
            "CFBundleShortVersionString": String(localized: "Short Version - Marketing version number", table: "EditorXcodePlugin"),
            "CFBundlePackageType": String(localized: "Package Type - Bundle package type", table: "EditorXcodePlugin"),
            "CFBundleSignature": String(localized: "Bundle Signature", table: "EditorXcodePlugin"),
            "LSMinimumSystemVersion": String(localized: "Minimum System Version - Minimum OS version", table: "EditorXcodePlugin"),
            "NSPrincipalClass": String(localized: "Principal Class", table: "EditorXcodePlugin"),
            "NSMainStoryboardFile": String(localized: "Main Storyboard - Main storyboard file", table: "EditorXcodePlugin"),
            "UILaunchStoryboardName": String(localized: "Launch Storyboard - Launch screen storyboard", table: "EditorXcodePlugin"),
            "UIApplicationSceneManifest": String(localized: "Scene Manifest - Scene configuration", table: "EditorXcodePlugin"),
            "UISupportedInterfaceOrientations": String(localized: "Supported Orientations - Supported interface orientations", table: "EditorXcodePlugin"),
            "UIRequiredDeviceCapabilities": String(localized: "Required Capabilities - Required device capabilities", table: "EditorXcodePlugin"),
            "NSAppTransportSecurity": String(localized: "App Transport Security - Network security", table: "EditorXcodePlugin"),
            "NSCameraUsageDescription": String(localized: "Camera Usage - Camera access description", table: "EditorXcodePlugin"),
            "NSPhotoLibraryUsageDescription": String(localized: "Photo Library Usage - Photo library access description", table: "EditorXcodePlugin"),
            "NSLocationWhenInUseUsageDescription": String(localized: "Location Usage - Location access description", table: "EditorXcodePlugin"),
            "NSBluetoothPeripheralUsageDescription": String(localized: "Bluetooth Usage - Bluetooth access description", table: "EditorXcodePlugin"),
        ]
    }
    
    /// 常见的 Entitlements key
    static var commonEntitlements: [String: String] {
        [
            "com.apple.security.application-groups": String(localized: "App Groups - Shared app group", table: "EditorXcodePlugin"),
            "com.apple.developer.icloud-container-identifiers": String(localized: "iCloud Containers", table: "EditorXcodePlugin"),
            "com.apple.developer.associated-domains": String(localized: "Associated Domains", table: "EditorXcodePlugin"),
            "com.apple.developer.applesignin": String(localized: "Sign in with Apple", table: "EditorXcodePlugin"),
            "com.apple.developer.networking.wifi-info": String(localized: "WiFi Info", table: "EditorXcodePlugin"),
            "com.apple.developer.usernotifications.communication": String(localized: "Communication Notifications", table: "EditorXcodePlugin"),
            "com.apple.developer.team-identifier": String(localized: "Team Identifier", table: "EditorXcodePlugin"),
            "keychain-access-groups": String(localized: "Keychain Access Groups", table: "EditorXcodePlugin"),
            "com.apple.security.device.audio-input": String(localized: "Audio Input", table: "EditorXcodePlugin"),
            "com.apple.security.device.camera": String(localized: "Camera", table: "EditorXcodePlugin"),
        ]
    }

    private static var plistEntries: [KnownEntry] {[
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
    ]}

    private static var entitlementEntries: [KnownEntry] {[
        .init(key: "com.apple.security.application-groups", description: commonEntitlements["com.apple.security.application-groups"] ?? "", valueSuggestions: ["group.$(PRODUCT_BUNDLE_IDENTIFIER)"]),
        .init(key: "com.apple.developer.associated-domains", description: commonEntitlements["com.apple.developer.associated-domains"] ?? "", valueSuggestions: ["applinks:example.com"]),
        .init(key: "com.apple.developer.applesignin", description: commonEntitlements["com.apple.developer.applesignin"] ?? "", valueSuggestions: ["Default"]),
        .init(key: "keychain-access-groups", description: commonEntitlements["keychain-access-groups"] ?? "", valueSuggestions: ["$(AppIdentifierPrefix)$(CFBundleIdentifier)"]),
        .init(key: "com.apple.security.device.camera", description: commonEntitlements["com.apple.security.device.camera"] ?? "", valueSuggestions: ["true"])
    ]}
    
    /// 验证 plist 内容
    static func validatePlist(_ content: String) -> [String] {
        var warnings: [String] = []
        
        // 检查是否包含常见但可能缺失的 key
        guard let data = content.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            warnings.append(String(localized: "Unable to parse as valid plist", table: "EditorXcodePlugin"))
            return warnings
        }
        
        // 检查是否包含必要字段
        if plist["CFBundleIdentifier"] == nil {
            warnings.append(String(localized: "Missing CFBundleIdentifier", table: "EditorXcodePlugin"))
        }
        if plist["CFBundleVersion"] == nil {
            warnings.append(String(localized: "Missing CFBundleVersion", table: "EditorXcodePlugin"))
        }
        if plist["CFBundleShortVersionString"] == nil {
            warnings.append(String(localized: "Missing CFBundleShortVersionString", table: "EditorXcodePlugin"))
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
            : "\n\n" + String(localized: "Suggested values:", table: "EditorXcodePlugin") + "\n" + entry.valueSuggestions.map { "- `\($0)`" }.joined(separator: "\n")
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
                detail: currentKey.map { String(localized: "Suggested value for \($0)", table: "EditorXcodePlugin") },
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
