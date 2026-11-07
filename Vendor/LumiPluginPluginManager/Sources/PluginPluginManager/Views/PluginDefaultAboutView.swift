import KernelCore
import LumiUI
import SwiftUI

/// 所有插件的默认关于页。
///
/// 插件可以贡献自己的品牌化 AboutView；没有贡献时，由插件管理器使用这
/// 个页面保证仍然提供完整、可读的插件说明。
struct PluginDefaultAboutView: View {
    @LumiTheme private var theme

    let metadata: PluginMetadata
    let isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LandingHero(
                icon: metadata.category.systemImage,
                accent: theme.primary,
                tagline: metadata.description.isEmpty
                    ? PluginPluginManagerText.noDetailsHint
                    : metadata.description,
                chips: [metadata.category.displayName, metadata.stage.displayName],
                metrics: [
                    .init(value: metadata.version, label: PluginPluginManagerText.versionLabel),
                    .init(value: policyValue, label: PluginPluginManagerText.policyLabel)
                ]
            )

            LandingSection(title: PluginPluginManagerText.coreCapabilities, icon: "info.circle") {
                LandingFeatureGrid(items: [
                    .init(
                        icon: metadata.category.systemImage,
                        tint: theme.primary,
                        title: PluginPluginManagerText.categoryLabel,
                        description: metadata.category.displayName
                    ),
                    .init(
                        icon: "checkmark.seal",
                        tint: theme.success,
                        title: "阶段",
                        description: metadata.stage.displayName
                    ),
                    .init(
                        icon: "lock.shield",
                        tint: theme.warning,
                        title: PluginPluginManagerText.policyLabel,
                        description: policyValue
                    ),
                    .init(
                        icon: "number.circle",
                        tint: theme.info,
                        title: PluginPluginManagerText.identifierLabel,
                        description: metadata.id
                    )
                ], minColumnWidth: 180)
            }

            if !metadata.permissions.isEmpty {
                LandingSection(title: PluginPluginManagerText.permissionsTitle, icon: "hand.raised") {
                    LandingInventory(
                        tint: theme.warning,
                        items: metadata.permissions.map {
                            .init(icon: "checkmark.shield", title: "\($0.id): \($0.reason)")
                        }
                    )
                }
            }
        }
    }

    private var policyValue: String {
        switch metadata.policy {
        case .required, .alwaysOn:
            PluginPluginManagerText.alwaysOn
        case .disabled:
            PluginPluginManagerText.disabledPermanently
        case .enabledByDefault, .disabledByDefault:
            isEnabled ? PluginPluginManagerText.enabled : PluginPluginManagerText.disabled
        }
    }
}
