import Foundation
import SwiftUI

// MARK: - Settings Section Context

/// 设置页 section 渲染上下文。
///
/// 当 section 在某个具体实体（如单个项目）的详情中渲染时，
/// 携带该实体的标识，供 section 视图按需获取数据。
/// 在 tab 顶部/底部等无实体上下文的位置渲染时，`projectPath` 为 `nil`。
@MainActor
public struct SettingsSectionContext: Sendable {
    /// 当前渲染所针对的项目路径（标准化前），仅当 section 在项目详情中渲染时有值。
    public let projectPath: String?

    public init(projectPath: String? = nil) {
        self.projectPath = projectPath
    }
}

// MARK: - Settings Section

/// 设置页 section 项。
///
/// 与 `SettingsTabItem`（整页 tab）不同，section 用于向**已存在的 tab 内容区**
/// 追加局部区块。插件通过 `settingsSections(kernel:)` 贡献，并指定 `tabID`
/// 挂载到目标 tab；由该 tab 的内容视图自行查询并渲染。
///
/// 典型场景：ProjectRAGPlugin 把"代码索引"区块挂载到 ProjectsPlugin 的"项目"
/// tab，从而出现在每个项目详情里，而无需 ProjectsPlugin 直接依赖 RAG 插件。
@MainActor
public struct SettingsSection: Identifiable, Sendable {
    /// 稳定唯一 id（同一 tab 内去重键）。
    public let id: String

    /// 挂载目标 tab 的 id（对应 `SettingsTabItem.id`）。
    public let tabID: String

    /// 排序键（升序）；同 order 时保持注册顺序。
    public var order: Int

    private let contentBuilder: @MainActor @Sendable (SettingsSectionContext) -> AnyView

    public init(
        id: String,
        tabID: String,
        order: Int,
        @ViewBuilder content: @escaping @MainActor @Sendable (SettingsSectionContext) -> some View
    ) {
        self.id = id
        self.tabID = tabID
        self.order = order
        self.contentBuilder = { AnyView(content($0)) }
    }

    /// 构建区块内容视图。
    /// - Parameter context: 当前渲染上下文（可能携带 `projectPath`）。
    public func makeContent(context: SettingsSectionContext) -> AnyView {
        contentBuilder(context)
    }
}

// MARK: - Well-known Settings Tab IDs

/// 约定俗成的设置 tab id 常量。
///
/// 供贡献方（`SettingsSection.tabID`）与宿主 tab（`SettingsTabItem.id`）双方引用，
/// 避免跨插件字符串硬编码漂移。
public enum LumiSettingsTabID {
    /// ProjectsPlugin 贡献的"项目"tab。
    public static let projects = "com.coffic.lumi.plugin.projects.settings"
}
