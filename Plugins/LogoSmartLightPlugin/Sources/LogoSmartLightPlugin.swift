import LumiCoreKit

public enum LogoSmartLightPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.lumi.plugin.logo-smart-light",
        displayName: LumiPluginLocalization.string("Smart Light Logo", bundle: .module),
        description: LumiPluginLocalization.string("Default animated logo with smart light effect", bundle: .module),
        order: 200
    )

    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta

    public static func logoItems(context: LumiPluginContext) -> [LumiLogoItem] {
        [
            LumiLogoItem(
                id: info.id,
                order: 200,
                makeView: { scene in
                    SmartLightLogoView(scene: scene)
                }
            )
        ]
    }
}
