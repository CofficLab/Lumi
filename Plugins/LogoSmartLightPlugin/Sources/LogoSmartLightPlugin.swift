import LumiCoreKit

public enum LogoSmartLightPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.lumi.plugin.logo-smart-light",
        displayName: "Smart Light Logo",
        description: "Default animated logo with smart light effect",
        order: 0
    )

    public static let policy: LumiPluginPolicy = .alwaysOn

    public static func logoItems(context: LumiPluginContext) -> [LumiLogoItem] {
        [
            LumiLogoItem(
                id: info.id,
                order: 0,
                makeView: { scene in
                    SmartLightLogoView(scene: scene)
                }
            )
        ]
    }
}
