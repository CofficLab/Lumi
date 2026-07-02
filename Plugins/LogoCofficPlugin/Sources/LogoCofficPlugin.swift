import LumiCoreKit

public enum LogoCofficPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.lumi.plugin.logo-coffic",
        displayName: LumiPluginLocalization.string("Coffic Logo", bundle: .module),
        description: LumiPluginLocalization.string("Coffee cup themed animated logo", bundle: .module),
        order: 100
    )

    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta

    public static func logoItems(context: LumiPluginContext) -> [LumiCore.LogoItem] {
        [
            LumiCore.LogoItem(
                id: info.id,
                order: 100,
                makeView: { scene in
                    CofficLogoView(scene: scene)
                }
            )
        ]
    }
}
