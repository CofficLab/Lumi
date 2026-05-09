import Foundation

/// Info.plist 和 .entitlements 编辑优化
public enum PlistEditing {
    public struct KnownEntry: Equatable {
        public let key: String
        public let description: String
        public let valueSuggestions: [String]

        public init(key: String, description: String, valueSuggestions: [String]) {
            self.key = key
            self.description = description
            self.valueSuggestions = valueSuggestions
        }
    }

    public struct KeyOccurrence: Equatable {
        public let key: String
        public let range: NSRange
        public let line: Int

        public init(key: String, range: NSRange, line: Int) {
            self.key = key
            self.range = range
            self.line = line
        }
    }

    /// 常见的 Info.plist key 及其描述
    public static var commonKeys: [String: String] {
        [
            "CFBundleName": "Bundle Name - Application name",
            "CFBundleDisplayName": "Display Name - Shown on Home screen",
            "CFBundleIdentifier": "Bundle ID - Unique app identifier",
            "CFBundleVersion": "Bundle Version - Build version number",
            "CFBundleShortVersionString": "Short Version - Marketing version number",
            "CFBundlePackageType": "Package Type - Bundle package type",
            "CFBundleSignature": "Bundle Signature",
            "LSMinimumSystemVersion": "Minimum System Version - Minimum OS version",
            "NSPrincipalClass": "Principal Class",
            "NSMainStoryboardFile": "Main Storyboard - Main storyboard file",
            "UILaunchStoryboardName": "Launch Storyboard - Launch screen storyboard",
            "UIApplicationSceneManifest": "Scene Manifest - Scene configuration",
            "UISupportedInterfaceOrientations": "Supported Orientations - Supported interface orientations",
            "UIRequiredDeviceCapabilities": "Required Capabilities - Required device capabilities",
            "NSAppTransportSecurity": "App Transport Security - Network security",
            "NSCameraUsageDescription": "Camera Usage - Camera access description",
            "NSPhotoLibraryUsageDescription": "Photo Library Usage - Photo library access description",
            "NSLocationWhenInUseUsageDescription": "Location Usage - Location access description",
            "NSBluetoothPeripheralUsageDescription": "Bluetooth Usage - Bluetooth access description",
        ]
    }

    /// 常见的 Entitlements key
    public static var commonEntitlements: [String: String] {
        [
            "com.apple.security.application-groups": "App Groups - Shared app group",
            "com.apple.developer.icloud-container-identifiers": "iCloud Containers",
            "com.apple.developer.associated-domains": "Associated Domains",
            "com.apple.developer.applesignin": "Sign in with Apple",
            "com.apple.developer.networking.wifi-info": "WiFi Info",
            "com.apple.developer.usernotifications.communication": "Communication Notifications",
            "com.apple.developer.team-identifier": "Team Identifier",
            "keychain-access-groups": "Keychain Access Groups",
            "com.apple.security.device.audio-input": "Audio Input",
            "com.apple.security.device.camera": "Camera",
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
        .init(key: "NSBluetoothPeripheralUsageDescription", description: commonKeys["NSBluetoothPeripheralUsageDescription"] ?? "", valueSuggestions: ["This app uses Bluetooth to connect to accessories."]),
    ]}

    private static var entitlementEntries: [KnownEntry] {[
        .init(key: "com.apple.security.application-groups", description: commonEntitlements["com.apple.security.application-groups"] ?? "", valueSuggestions: ["group.$(PRODUCT_BUNDLE_IDENTIFIER)"]),
        .init(key: "com.apple.developer.associated-domains", description: commonEntitlements["com.apple.developer.associated-domains"] ?? "", valueSuggestions: ["applinks:example.com"]),
        .init(key: "com.apple.developer.applesignin", description: commonEntitlements["com.apple.developer.applesignin"] ?? "", valueSuggestions: ["Default"]),
        .init(key: "keychain-access-groups", description: commonEntitlements["keychain-access-groups"] ?? "", valueSuggestions: ["$(AppIdentifierPrefix)$(CFBundleIdentifier)"]),
        .init(key: "com.apple.security.device.camera", description: commonEntitlements["com.apple.security.device.camera"] ?? "", valueSuggestions: ["true"]),
    ]}

    /// 验证 plist 内容
    public static func validatePlist(_ content: String) -> [String] {
        var warnings: [String] = []

        guard let data = content.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            warnings.append("Unable to parse as valid plist")
            return warnings
        }

        if plist["CFBundleIdentifier"] == nil {
            warnings.append("Missing CFBundleIdentifier")
        }
        if plist["CFBundleVersion"] == nil {
            warnings.append("Missing CFBundleVersion")
        }
        if plist["CFBundleShortVersionString"] == nil {
            warnings.append("Missing CFBundleShortVersionString")
        }

        return warnings
    }

    /// 快速跳转到指定 key（在 XML 中定位）
    public static func findKeyLocation(in content: String, key: String) -> NSRange? {
        let keyPattern = "<key>\\s*\(NSRegularExpression.escapedPattern(for: key))\\s*</key>"
        guard let regex = try? NSRegularExpression(pattern: keyPattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: content, range: NSRange(location: 0, length: content.utf16.count)) else {
            return nil
        }
        return match.range
    }

    public static func supports(fileURL: URL) -> Bool {
        let ext = fileURL.pathExtension.lowercased()
        return ext == "plist" || ext == "entitlements"
    }

    public static func hoverMarkdown(for key: String, fileURL: URL) -> String? {
        guard supports(fileURL: fileURL),
              let entry = entry(forKey: key, fileURL: fileURL) else {
            return nil
        }

        let values = entry.valueSuggestions.isEmpty
            ? ""
            : "\n\nSuggested values:\n" + entry.valueSuggestions.map { "- `\($0)`" }.joined(separator: "\n")
        return "### `\(entry.key)`\n\(entry.description)\(values)"
    }

    public static func completionSuggestions(
        prefix: String,
        line: Int,
        character: Int,
        content: String,
        fileURL: URL
    ) -> [PlistCompletionSuggestion] {
        guard supports(fileURL: fileURL) else { return [] }
        let normalizedPrefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let entries = knownEntries(for: fileURL)
        let matchingKeys = entries.filter {
            normalizedPrefix.isEmpty || $0.key.lowercased().hasPrefix(normalizedPrefix)
        }

        let currentKey = PlistEditing.currentKey(in: content, line: line, character: character)
        let matchingValues = currentKey
            .flatMap { entry(forKey: $0, fileURL: fileURL) }?
            .valueSuggestions
            .filter { normalizedPrefix.isEmpty || $0.lowercased().contains(normalizedPrefix) } ?? []

        let keySuggestions = matchingKeys.enumerated().map { index, entry in
            PlistCompletionSuggestion(
                label: entry.key,
                insertText: entry.key,
                detail: entry.description,
                priority: 220 - index
            )
        }

        let valueSuggestions = matchingValues.enumerated().map { index, value in
            PlistCompletionSuggestion(
                label: value,
                insertText: value,
                detail: currentKey.map { "Suggested value for \($0)" },
                priority: 260 - index
            )
        }

        return valueSuggestions + keySuggestions
    }

    public static func currentKey(in content: String, line: Int, character: Int) -> String? {
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

    public static func keyOccurrences(in content: String) -> [KeyOccurrence] {
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

/// Plist 补全建议（XcodeKit 内部使用的类型，不依赖 EditorService）
public struct PlistCompletionSuggestion {
    public let label: String
    public let insertText: String
    public let detail: String?
    public let priority: Int

    public init(label: String, insertText: String, detail: String?, priority: Int) {
        self.label = label
        self.insertText = insertText
        self.detail = detail
        self.priority = priority
    }
}
