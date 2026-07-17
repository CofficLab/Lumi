import EditorService
import LumiCoreKit
import LumiUI
import SwiftUI
import os

public enum StripHeaderPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-tab-strip")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.editor-tab-strip-header",
        displayName: LumiPluginLocalization.string("Editor Tab Strip", bundle: .module),
        description: LumiPluginLocalization.string("Tab bar for the editor panel.", bundle: .module),
        order: 70,
        category: .development,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "rectangle.topthird.inset.filled",
    )

    @MainActor
    public static func panelHeaderItems(context: LumiPluginContext) -> [LumiPanelHeaderItem] {
        bootstrapFromLumiCoreIfNeeded(context: context)
        guard context.showsPanelChrome else {
            return []
        }
        guard let lumiCore = context.lumiCore else { return [] }

        // LumiEditorServicing 不可用时显示错误视图
        guard let service = context.resolve(LumiEditorServicing.self)?.editorService else {
            return [
                LumiPanelHeaderItem(id: "\(info.id).error") {
                    StripHeaderErrorView(pluginName: info.displayName)
                }
            ]
        }

        return [
            LumiPanelHeaderItem(id: info.id) {
                HeaderView(service: service, lumiCore: lumiCore)
            }
        ]
    }
}
