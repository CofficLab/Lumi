import Foundation
import EditorService
import LumiCoreKit
import SwiftUI

/// 编辑器 decoration 样例插件：演示 git-like 与 custom gutter decoration 的接入方式。
public enum SampleDecorationEditorPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "signpost.right.and.left"

    public static let info = LumiPluginInfo(
        id: "SampleDecorationEditor",
        displayName: LumiPluginLocalization.string("Sample Decoration", bundle: .module),
        description: LumiPluginLocalization.string("Demonstrates sample gutter decorations for the editor extension surface.", bundle: .module),
        order: 90
    )

    public static func registerEditorExtensions(into registry: AnyObject) async {
        guard let registry = registry as? EditorExtensionRegistry else { return }
        registry.registerDecorationContributor(SampleDecorationContributor())
    }
}
