import LumiKernel

public enum LogoSmartLightPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "com.lumi.plugin.logo-smart-light",
        displayName: LumiPluginLocalization.string("Smart Light Logo", bundle: .module),
        description: LumiPluginLocalization.string("Default animated logo with smart light effect", bundle: .module),
        order: 200,
        policy: .alwaysOn,
        stage: .beta,
    )


    public static func logoItems(context: LumiPluginContext) -> [LogoItem] {
        [
            LogoItem(
                id: info.id,
                order: info.order,
                makeView: { scene in
                    SmartLightLogoView(scene: scene)
                }
            )
        ]
    }
}
