import Foundation
import AppKit

/// Info.plist 和 .entitlements 编辑优化
/// 对应 Phase 7: plist / entitlements 编辑优化
enum PlistEditing {
    
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
}
