import Foundation
import ProviderSkill

/// Xcode Build 技能贡献者：演示第三方插件如何贡献 Skill。
///
/// 实现 `SkillContributing`（`Sendable` 值类型），在 `onBoot` 时通过
/// `SkillProviding.addProvider(_:)` 注入。技能正文内嵌（不依赖磁盘文件），
/// 插件卸载时按 `providerID` 幂等撤回。
public struct XcodeBuildSkillContributor: SkillContributing {
    public let providerID: String

    public init(providerID: String = XcodeBuildPlugin.pluginID) {
        self.providerID = providerID
    }

    public var allSkills: [SkillMetadata] {
        [
            SkillMetadata(
                name: "xcode-build",
                title: "Xcode Build",
                description: "在涉及 Xcode 工程编译、构建错误、签名与模拟器问题时，按本规范引导构建流程。",
                triggers: ["xcode", "build", "编译", "签名", "模拟器"],
                version: "1.0.0",
                content: Self.skillContent
            ),
        ]
    }

    /// SKILL.md 正文（内嵌字符串；实际场景也可从 Bundle 资源加载）。
    public static let skillContent = """
    # Xcode Build 规范

    当任务涉及 Xcode 工程编译时，遵循以下步骤：

    1. 先确认工程根目录：查找 `.xcodeproj` 或 `Package.swift`。
    2. 区分目标：App / Framework / Package，使用对应 `xcodebuild` 参数。
    3. 构建命令：
       - `xcodebuild -project Foo.xcodeproj -scheme Foo -configuration Debug build`
       - `xcodebuild -destination 'platform=iOS Simulator,name=iPhone 15' build`
    4. 遇到构建错误先读取完整 error 上下文，不要只看最后一行。
    5. 签名问题（code signing）通常需要检查 Signing & Capabilities 与
       DEVELOPMENT_TEAM 配置。
    6. 模拟器问题优先检查 destination 名称是否与当前 Xcode 支持的模拟器匹配。
    """
}