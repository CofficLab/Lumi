import SwiftUI

// MARK: - Setting Entry Item

/// 设置入口项（由外部注入）。
///
/// 类似 Lumi 的 `SettingsTabItem`：在设置界面左侧的侧边栏显示一个入口，
/// 点击切换右侧的详情视图。
@MainActor
public struct SettingEntryItem: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    public var order: Int
    /// 详情视图。
    public let makeDetailView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        title: String,
        systemImage: String,
        order: Int = 200,
        @ViewBuilder detail: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.order = order
        self.makeDetailView = { AnyView(detail()) }
    }
}
