import SwiftUI

/// 设置视图提供能力协议
///
/// 定义「内核 → 设置窗口内容」这一段的最小契约：宿主在启动时
/// 通过内核解析 `SettingViewProviding`，拿到设置视图后作为设置窗口内容展示。
///
/// 协议只声明能力，不关心具体实现：
/// - 外部通过 `registerEntries(_:)`（替换）或 `addEntries(_:)`（追加）
///   注入 `SettingEntryItem`（侧边栏入口）；
/// - 实现负责把注入的入口渲染成「左侧入口列表 + 右侧详情视图」的设置界面
///   （`makeSettingView()`）。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any SettingViewProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public protocol SettingViewProviding: AnyObject {
    /// 当前已注入的全部设置入口项。
    var entries: [SettingEntryItem] { get }

    /// 注入设置入口项（替换当前全部项）。
    func registerEntries(_ entries: [SettingEntryItem])

    /// 追加设置入口项（保留已有项）。
    ///
    /// 供多个插件各自贡献入口时使用，互不覆盖。
    func addEntries(_ entries: [SettingEntryItem])

    /// 按 id 撤回插件贡献的入口。
    func removeEntries(ids: Set<String>)

    /// 返回设置视图（基于已注入的入口渲染）。
    func makeSettingView() -> AnyView
}

public extension SettingViewProviding {
    /// 追加语义的默认实现：合入已有入口并按 `order` 排序（同 id 去重，保留先注册者）。
    func addEntries(_ newEntries: [SettingEntryItem]) {
        var merged = entries
        for entry in newEntries where !merged.contains(where: { $0.id == entry.id }) {
            merged.append(entry)
        }
        registerEntries(merged)
    }

    func removeEntries(ids: Set<String>) {
        registerEntries(entries.filter { !ids.contains($0.id) })
    }
}

// MARK: - Optional Selection & Sidebar Header

public extension SettingViewProviding where Self: ObservableObject {
    /// 当前选中入口的 id。默认 `nil`（无选中）。
    var selectedEntryID: String? { nil }

    /// 选中指定入口。默认 no-op。
    func selectEntry(id: String?) {}

    /// 侧边栏顶部的自定义 Header（如 Logo + 应用名）。默认 `nil`。
    var sidebarHeader: AnyView? { nil }
}
