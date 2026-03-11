import AppKit
import SwiftUI

// MARK: - Agent View Methods

extension SuperPlugin {
    /// 添加侧边栏视图（用于 Agent 模式）
    ///
    /// 在 Agent 模式下显示于屏幕左侧的视图。
    /// 多个插件的侧边栏视图会从上到下垂直堆叠显示。
    /// 常用于：
    /// - 对话列表
    /// - 文件树
    /// - 项目结构
    ///
    /// - Returns: 要添加的侧边栏视图，如果不需要则返回 nil
    /// - Note: 在 Agent 模式下，插件可以提供自定义的侧边栏视图，多个插件的侧边栏会从上到下垂直堆叠显示
    @MainActor func addSidebarView() -> AnyView?

    /// 添加中间栏视图（用于 Agent 模式）
    ///
    /// 在 Agent 模式下显示于侧边栏和详情栏之间的视图。
    /// 多个插件的中间栏视图会从上到下垂直堆叠显示。
    /// 常用于：
    /// - 文件预览
    /// - 代码查看器
    /// - 媒体预览
    ///
    /// - Returns: 要添加的中间栏视图，如果不需要则返回 nil
    /// - Note: 在 Agent 模式下，插件可以提供自定义的中间栏视图，位于侧边栏和详情栏之间，多个插件的中间栏会从上到下垂直堆叠显示
    @MainActor func addMiddleView() -> AnyView?

    /// 添加详情栏头部视图（用于 Agent 模式）
    ///
    /// 在 Agent 模式下显示于详情栏顶部的视图。
    /// 多个插件的头部视图会从上到下垂直堆叠显示。
    /// 常用于：
    /// - 聊天头部信息
    /// - 工具栏
    /// - 搜索框
    ///
    /// - Returns: 要添加的详情栏头部视图，如果不需要则返回 nil
    /// - Note: 在 Agent 模式下，插件可以提供自定义的详情栏头部视图，多个插件的头部视图会从上到下垂直堆叠显示
    @MainActor func addDetailHeaderView() -> AnyView?

    /// 添加详情栏中间视图（用于 Agent 模式）
    ///
    /// 在 Agent 模式下显示于详情栏中部的视图。
    /// 多个插件的中间视图会从上到下垂直堆叠显示。
    /// 此区域通常用于显示主要内容和消息列表。
    ///
    /// - Returns: 要添加的详情栏中间视图，如果不需要则返回 nil
    /// - Note: 在 Agent 模式下，插件可以提供自定义的详情栏中间视图（消息列表），多个插件的中间视图会从上到下垂直堆叠显示
    @MainActor func addDetailMiddleView() -> AnyView?

    /// 添加详情栏底部视图（用于 Agent 模式）
    ///
    /// 在 Agent 模式下显示于详情栏底部的视图。
    /// 多个插件的底部视图会从上到下垂直堆叠显示。
    /// 常用于：
    /// - 输入区域
    /// - 发送按钮
    /// - 附件上传
    ///
    /// - Returns: 要添加的详情栏底部视图，如果不需要则返回 nil
    /// - Note: 在 Agent 模式下，插件可以提供自定义的详情栏底部视图（输入区域），多个插件的底部视图会从上到下垂直堆叠显示
    @MainActor func addDetailBottomView() -> AnyView?
}

// MARK: - Agent View Default Implementation

extension SuperPlugin {
    /// 默认实现：不提供侧边栏视图
    @MainActor func addSidebarView() -> AnyView? { nil }

    /// 默认实现：不提供中间栏视图
    @MainActor func addMiddleView() -> AnyView? { nil }

    /// 默认实现：不提供详情栏头部视图
    @MainActor func addDetailHeaderView() -> AnyView? { nil }

    /// 默认实现：不提供详情栏中间视图
    @MainActor func addDetailMiddleView() -> AnyView? { nil }

    /// 默认实现：不提供详情栏底部视图
    @MainActor func addDetailBottomView() -> AnyView? { nil }
}
