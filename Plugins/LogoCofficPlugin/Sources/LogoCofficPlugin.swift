import LumiCoreKit

public enum LogoCofficPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.lumi.plugin.logo-coffic",
        displayName: "Coffic Logo",
        description: "Coffee cup themed animated logo",
        order: 100
    )

    public static let policy: LumiPluginPolicy = .alwaysOn

    public static func logoItems(context: LumiPluginContext) -> [LumiLogoItem] {
        [
            LumiLogoItem(
                id: info.id,
                order: 100,
                makeView: { scene in
                    CofficLogoView(scene: scene)
                }
            )
        ]
    }
}
