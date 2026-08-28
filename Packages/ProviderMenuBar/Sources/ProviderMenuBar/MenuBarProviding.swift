import SwiftUI

/// 菜单栏提供能力协议
///
/// 定义「内核 → 系统菜单栏」这一段的最小契约：插件在 `onBoot` 中解析
/// `MenuBarProviding`，通过 `addContent(_:)` / `addPopup(_:)` 注入
/// 自己的菜单栏内容与弹窗；宿主（macOS App）用 `MenuBarExtra` 场景
/// 渲染 `makeContentView()` / `makePopupView()`。
///
/// 采用追加语义（多插件各自贡献），与 `SettingViewProviding.addEntries`
/// 一致。协议只声明能力，不关心具体实现。
///
/// 使用 `AnyView` 而非 `associatedtype`：协议可无泛型约束地作为存在类型
/// （`any MenuBarProviding`）注册进 KernelCore 的 `[ObjectIdentifier: Any]` 注册表。
@MainActor
public protocol MenuBarProviding: AnyObject, ObservableObject {
    /// 全部菜单栏内容项。
    var contentItems: [MenuBarContentItem] { get }

    /// 全部菜单栏弹窗项。
    var popupItems: [MenuBarPopupItem] { get }

    /// 替换全部内容项（供追加实现内部使用，或宿主全量设置）。
    func replaceContentItems(_ items: [MenuBarContentItem])

    /// 替换全部弹窗项。
    func replacePopupItems(_ items: [MenuBarPopupItem])

    /// 追加一个内容项（同 id 去重，保留先注册者）。
    func addContent(_ item: MenuBarContentItem)

    /// 追加一个弹窗项（同 id 去重，保留先注册者）。
    func addPopup(_ item: MenuBarPopupItem)

    /// 按 id 撤回内容项与弹窗项。
    func removeItems(ids: Set<String>)

    /// 返回菜单栏内容视图（合并多个内容项）。
    func makeContentView() -> AnyView

    /// 返回菜单栏弹窗视图（合并多个弹窗项）。
    func makePopupView() -> AnyView
}

public extension MenuBarProviding {
    /// 追加语义的默认实现：合入已有内容项（同 id 去重）。
    func addContent(_ item: MenuBarContentItem) {
        var merged = contentItems
        if !merged.contains(where: { $0.id == item.id }) {
            merged.append(item)
        }
        replaceContentItems(merged)
    }

    /// 追加语义的默认实现：合入已有弹窗项（同 id 去重）。
    func addPopup(_ item: MenuBarPopupItem) {
        var merged = popupItems
        if !merged.contains(where: { $0.id == item.id }) {
            merged.append(item)
        }
        replacePopupItems(merged)
    }

    func removeItems(ids: Set<String>) {
        replaceContentItems(contentItems.filter { !ids.contains($0.id) })
        replacePopupItems(popupItems.filter { !ids.contains($0.id) })
    }

    /// 默认内容视图：按 order 排序后横向合并。
    func makeContentView() -> AnyView {
        AnyView(
            HStack(spacing: 4) {
                ForEach(contentItems.sorted { $0.order < $1.order }) { item in
                    item.makeView()
                        .help(item.title)
                }
            }
        )
    }

    /// 默认弹窗视图：按 order 排序后纵向合并。
    func makePopupView() -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                ForEach(popupItems.sorted { $0.order < $1.order }) { item in
                    item.makeView()
                }
            }
            .padding(12)
        )
    }
}
