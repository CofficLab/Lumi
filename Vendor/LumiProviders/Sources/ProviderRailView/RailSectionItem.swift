import SwiftUI

/// Rail 中由插件贡献的纵向区块。
///
/// 该类型保留旧版 Rail 的区块式装配能力，和 tab 式 Rail 可以同时存在。
@MainActor
public struct RailSectionItem: Identifiable {
    public let id: String
    public let order: Int
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        order: Int = 0,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.order = order
        self.makeView = { AnyView(content()) }
    }
}
