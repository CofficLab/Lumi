import LumiCoreKit

public enum LogoCofficPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.lumi.plugin.logo-coffic",
        displayName: LumiPluginLocalization.string("Coffic Logo", bundle: .module),
        description: LumiPluginLocalization.string("Coffee cup themed animated logo", bundle: .module),
        order: 100,
        policy: .alwaysOn,
        stage: .beta,
    )


    public static func logoItems(context: any LumiCoreAccessing) -> [LogoItem] {
        [
            LogoItem(
                id: info.id,
                order: info.order,
                makeView: { scene in
                    CofficLogoView(scene: scene)
                }
            )
        ]
    }
}
