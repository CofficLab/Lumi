import Foundation
import SwiftUI

// MARK: - Onboarding Page Item

/// 引导页项
///
/// 插件通过 `kernel.registerOnboardingPage()` 注册引导页。
///
/// 注意：`order` 由内核自动从插件继承，无需手动指定。
@MainActor
public struct OnboardingPageItem: Identifiable, Sendable {
    public let id: String
    public var order: Int
    public let makeView: @MainActor @Sendable () -> AnyView

    /// 公开初始化器（不包含 order）
    public init<Content: View>(
        id: String,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = 200  // 默认值，内核会覆盖
        self.makeView = { AnyView(content()) }
    }

    /// 内部初始化器（用于内核设置 order）
    internal init<Content: View>(
        id: String,
        order: Int,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = order
        self.makeView = { AnyView(content()) }
    }
}

// MARK: - Onboarding Capability Protocol

/// 引导页能力协议
///
/// 定义 LumiCore 需要的引导页管理功能，由具体插件实现。
/// 负责管理所有插件的引导页注册、排序和查询。
@MainActor
public protocol OnboardingProviding: ObservableObject {
    /// 所有已注册的引导页项（按 order 排序）
    var allOnboardingPages: [OnboardingPageItem] { get }

    /// 注册引导页项
    func registerOnboardingPage(_ page: OnboardingPageItem)

    /// 注销引导页项
    func unregisterOnboardingPage(id: String)
}
