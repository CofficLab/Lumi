import EditorService
import LumiCoreKit
import LumiPreviewKit
import Foundation
import SwiftUI
import os

/// Runtime configuration for inline preview.
public enum EditorPreviewPlugin: LumiPlugin {

    public static let info = LumiPluginInfo(
        id: "EditorPreview",
        displayName: LumiPluginLocalization.string("Inline Preview", bundle: .module),
        description: LumiPluginLocalization.string("Embedded preview powered by LumiPreviewKit", bundle: .module),
        order: 84,
        category: .development,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "rectangle.inset.filled",
    )
}
