import SwiftUI
import LumiUI
import LumiCoreKit
import SuperLogKit
import os

public enum ModelPreferencePlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .system
    public static let iconName = "target"

    public static let info = LumiPluginInfo(
        id: "ModelPreference",
        displayName: LumiPluginLocalization.string("Model Preference", bundle: .module),
        description: LumiPluginLocalization.string("Remember provider and model per conversation", bundle: .module),
        order: 100
    )
}
