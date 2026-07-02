import LumiCoreKit
import SwiftUI

/// 布局持久化插件
/// 实现 LumiLayoutPersistence 协议，提供布局数据的读写能力
public enum LayoutPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .general
    public static let iconName = "sidebar.left"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.layout",
        displayName: LumiPluginLocalization.string("Layout Persistence", bundle: .module),
        description: LumiPluginLocalization.string("Persist and restore layout state across app launches", bundle: .module),
        order: 99
    )

    // MARK: - LumiPlugin Lifecycle

    /// 插件注册时注入持久化实现
    @MainActor
    public static func lifecycle(_ event: LumiPluginLifecycle) {
        switch event {
        case .didRegister:
            break
        case .appDidLaunch:
            break
        case .projectDidOpen:
            break
        case .projectDidClose:
            break
        }
    }

    // MARK: - LumiPlugin Implementation

    @MainActor
    public static func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem] {
        [
            LumiRootOverlayItem(id: info.id, order: info.order) { content in
                LayoutPersistenceAnchor(content: content)
            }
        ]
    }

    @MainActor
    public static func titleToolbarItems(context: LumiPluginContext) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(info.id).layout-menu",
                title: LumiPluginLocalization.string("Layout", bundle: .module),
                placement: .trailing
            ) {
                LayoutMenuButton()
            }
        ]
    }
}

// MARK: - Persistence Anchor

private struct LayoutPersistenceAnchor: View {
    let content: AnyView
    private let persistence = LayoutPluginLocalStore.shared

    var body: some View {
        content
    }
}
